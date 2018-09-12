clear; close all;

%USER ADJUSTED PARAMETERS BELOW
outputformat = '.klb'; %comment/uncomment the type of format that you want
% outputformat = '.tif';
registerConcurrently = true;
crop_and_mask_image = true;

computeTimeSeriesMaxProjection=true; %registered 3D time series max projection while doing file conversions
computeTimeSeriesMeanProjection=true;

writeTimeSliceMovies = true; %Note, this writes 8bit movies scaled to the max && computeMaxProjection must be true;
% writeKeyImage=true;
%%%%registration optimizer and metric options here

regParameters = NaN;

if registerConcurrently
    writeKeyImage = true;
else
    writeKeyImage = false;
end

[optimizer,metric]=imregconfig('multimodal'); %use multimodal for mutual information, monomodal for gradient descent
optimizer.InitialRadius=1.0e-5;
optimizer.Epsilon = 5.0e-5;
optimizer.GrowthFactor=4.50;
optimizer.MaximumIterations=2000;

% [optimizer,metric]=imregconfig('monomodal'); %use multimodal for mutual information, monomodal for gradient descent
% optimizer.GradientMagnitudeTolerance=1e-9;
% optimizer.MinimumStepLength=1e-9;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%set up multi-core processing
% defaultProfile = parallel.defaultClusterProfile;
% myCluster = parcluster(defaultProfile);
% maxWorkers = myCluster.NumWorkers;
% 
% localRun(2) = min(feature('numcores'), maxWorkers);
% 
% disp(' ');
% disp([num2str(localRun(2)) ' CPU cores were detected and will be allocated for parallel processing.']);
% disp(' ');
% 
% %memory usage estimation 
% % jobMemory    = [1 0];  
% % unitX = 2 * prod(stDim) / (1024 ^ 3);
% % jobMemory(1, 2) = ceil(1.2 * unitX); %no rotation condition in clusterPT script
% 
% % if matlabpool('size') > 0
% %     matlabpool('close');
% % end;
% % matlabpool(localRun(2));
% poolObj=parpool('local',localRun(2));
% 
% 
% disp(' ');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[PATH] = uigetdir(pwd, 'select .stack directory');
cd(PATH)

StackData = dir('*stack'); %list all .stack files in the directory
xmlHeader = dir('*.xml');

fs=filesep;


%check for incomplete .stack files
fileByteList = vertcat(StackData.bytes);
trueSize = median(fileByteList);
suspicious_sizes = fileByteList ~= trueSize;

if sum(suspicious_sizes)
    flaggedFiles = vertcat(StackData(suspicious_sizes).name);
    disp('Suspicious file sizes detected:');
    disp(flaggedFiles);
    error('Files are not all the same bytes!');
end


% %%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
xmlInfo = xmlread(xmlHeader.name);
pushConfig = xmlInfo.getDocumentElement;
sInfo = pushConfig.getElementsByTagName('info');

for k=0:sInfo.getLength-1 %grab convoluted .xml info header
   sInfoTxt{k+1,1} = char(sInfo.item(k).getAttributes.item(0).toString); 
end

timestamp_l = regexp(sInfoTxt,'timestamp="([\w,:,.,\s,/]+)"','tokens');
timestamp = timestamp_l{arrayfun(@(x) ~isempty(x{1}), timestamp_l)}{1};

zstep_l = regexp(sInfoTxt,'z_step="([\w,:,.,\s,/]+)"','tokens');
zstep = zstep_l{arrayfun(@(x) ~isempty(x{1}), zstep_l)}{1};

xy_microns_per_pixel = 0.41;

dimensions_l = regexp(sInfoTxt,'dimensions="([\w,:,.,\s,/]+)"','tokens');
dimensions_str = dimensions_l{arrayfun(@(x) ~isempty(x{1}), dimensions_l)}{1};
stDim_cell = regexp(dimensions_str,'x','Split'); %extract dimensions of stack
stDim = arrayfun(@(x) str2num(x{1}), stDim_cell{1});

%%%%%%%%%%%%%%%%%%ordering the stacks
cellregmatch = cellfun(@(x) regexp(x, 'TM[0-9]+','match'), {StackData.name},'UniformOutput',false);
listorder = arrayfun(@(x) str2num(x{1}{1}(3:end)), cellregmatch)';
sortList = sortrows([listorder, [1:numel(cellregmatch)]'],1);


%%%%%%CROP and MASK GUI
% tic %memmapfile method is an order of magnitude faster at reading!
% stack1 = multibandread(StackData(1).name, [stDim(2) stDim(1) stDim(3)], ...
%     '*uint16', 0, 'bsq', 'ieee-le');
% toc


if crop_and_mask_image
    memMap = memmapfile(StackData(1).name,'Format','uint16');
    filedata = memMap.Data;

    % stack1 = reshape(filedata,stDim); %if you don't mind the 90degree rotation, halves read time (~0.2 seconds)
    stack1  = reshape(filedata,stDim);
    stack1MxProj = max(stack1,[],3)';
    [crop,intMask]=StackCropperGUI(stack1MxProj);
else
    crop=[1 stDim(1) 1 stDim(2)];
    intMask=0;
end

cropParameters.crop=crop;
cropParameters.mask=intMask;

numStacks = numel(StackData);

    
if registerConcurrently

    seriesMidPt = floor(numStacks/2);
    memMap = memmapfile(StackData(seriesMidPt).name,'Format','uint16');
    filedata = memMap.Data;
    stackMid  = permute(reshape(filedata,stDim),[2,1,3]);
    stackMidMx = max(stackMid,[],3);
    
    regParameters=Stack2DRegistrationGUI(stackMidMx,PATH,optimizer,metric);
    
    


    if (regParameters.cropRegion(1) < crop(1)) || ...
       (sum(regParameters.cropRegion(1:2))-1 > sum(crop(1:2))-1) || ...
       (regParameters.cropRegion(3) < crop(3)) || ...
       (sum(regParameters.cropRegion(3:4))-1 > sum(crop(3:4))-1)
   
       error('Registration crop is outside of stack crop');
       
    end
    
end

convert.regParameters = regParameters;
convert.cropParameters = cropParameters;
convert.optimizer = optimizer;
convert.metric = metric;
convert.outputformat = outputformat;
convert.registerConcurrently = registerConcurrently;
convert.crop_and_mask_image = crop_and_mask_image;
convert.computeMax = computeTimeSeriesMaxProjection;
convert.computeMean = computeTimeSeriesMeanProjection;
convert.writeTimeSliceMovies = writeTimeSliceMovies;
convert.fetchKey = writeKeyImage;

save conversionParameters convert