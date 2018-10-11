system_shutdown_after_completion = true;
fs=filesep;
%replace this with a list of directories containing the
%conversionParameters.mat file

expt_directories = {...
                'E:\Dawnis\IndependenceDay\L07\PreQuench\_20170704_115018'...
                'E:\Dawnis\IndependenceDay\L07\PreQuench\_20170704_115041'...
                'E:\Dawnis\IndependenceDay\L07\SptSTructural\_20170704_131757'...
                'E:\Dawnis\IndependenceDay\L07\SptSTructural\_20170704_131811'...
                'E:\Dawnis\IndependenceDay\L07\SptSTructural\_20170704_131820'...
                ...
                'E:\Dawnis\IndependenceDay\L07\PreQuench\_20170704_115453'...
                'E:\Dawnis\IndependenceDay\L07\PreQuench\_20170704_115512'...
                'E:\Dawnis\IndependenceDay\L07\PostSpinal Structural\_20170704_142322'...
                'E:\Dawnis\IndependenceDay\L07\PostSpinal Structural\_20170704_142335'...
                'E:\Dawnis\IndependenceDay\L07\PostSpinal Structural\_20170704_142351'...
                ...
                'F:\Dawnis\IndieL08\PreQuench Structural\_20170704_150013'...
                'F:\Dawnis\IndieL08\PreQuench Structural\_20170704_150028'...
                'F:\Dawnis\IndieL08\ShckHBStructural\_20170704_165716'...
                'F:\Dawnis\IndieL08\ShckHBStructural\_20170704_165723'...
                'F:\Dawnis\IndieL08\ShckHBStructural\_20170704_165738'...
                'F:\Dawnis\IndieL08\ShckHBStructural\_20170704_165755'...
    };

%add any co-label folders (containing the red channel) here. These folders
%MUST have a copy of the conversionParameters.mat file that matches their
%parent trial in them. 

colabel_directories = { ...
            'E:\Dawnis\IndependenceDay\L07\PreQuench\_20170704_115453'...
    };

%DO NOT CHANGE ANYTHING BELOW THIS LINE

list_of_directories = [expt_directories, colabel_directories];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for directory_idx  = 1:numel(list_of_directories)
    cd(list_of_directories{directory_idx});
    
    disp(sprintf('Converting %s',list_of_directories{directory_idx}));
    load conversionParameters;
    % clear all;

    if directory_idx > numel(expt_directories)
        convert.registerConcurrently = false;
        convert.computeMax = false;
        convert.computeMean = false;
        convert.outputformat = '.tif';
        convert.writeKeyImage = false;
        convert.writeTimeSliceMovies = false;
        convert.cropParameters.mask = 0;
    end
    
    %load user parameters
    outputformat = convert.outputformat; %comment/uncomment the type of format that you want
    % outputformat = '.tif';
    registerConcurrently = convert.registerConcurrently;
    crop_and_mask_image = convert.crop_and_mask_image;


    computeTimeSeriesMaxProjection=convert.computeMax; %registered 3D time series max projection while doing file conversions
    computeTimeSeriesMeanProjection=convert.computeMean;
    writeKeyImage=convert.fetchKey;
    %%%%registration optimizer and metric options here
    %load optimizer for registration
    optimizer = convert.optimizer;
    metric = convert.metric;

    StackData = dir('*stack'); %list all .stack files in the directory
    xmlHeader = dir('*.xml');

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


    crop = convert.cropParameters.crop;
    intMask = convert.cropParameters.mask;
    cropParameters.crop=crop;
    cropParameters.mask=intMask;

    numStacks = numel(StackData);
    projectionTime = NaN;
    
    if registerConcurrently

        seriesMidPt = floor(numStacks/2);
        memMap = memmapfile(StackData(seriesMidPt).name,'Format','uint16');
        filedata = memMap.Data;
        stackMid  = permute(reshape(filedata,stDim),[2,1,3]);
        stackMidMx = max(stackMid,[],3);

        regParameters=convert.regParameters;   
%         regParameters=convert.regParaeters;  %typo from before

        if (regParameters.cropRegion(1) < crop(1)) || ...
           (sum(regParameters.cropRegion(1:2))-1 > sum(crop(1:2))-1) || ...
           (regParameters.cropRegion(3) < crop(3)) || ...
           (sum(regParameters.cropRegion(3:4))-1 > sum(crop(3:4))-1)

           error('Registration crop is outside of stack crop');

        end

        xStart=regParameters.cropRegion(1);
        yStart=regParameters.cropRegion(3);
        xLength=regParameters.cropRegion(2);
        yLength=regParameters.cropRegion(4);

        proj2D_mat = zeros(xLength,yLength,numStacks); %pre-allocate 2D projections matrix
        
    tic;
    parfor t=1:numStacks %compute projections in parallel

        disp(sprintf('computing 2d projction for stack %03d',t));

        memMap = memmapfile(StackData(t).name,'Format','uint16');
        filedata = memMap.Data;     

        stackFull = reshape(filedata,stDim); 
        stack = stackFull(xStart:xStart+xLength-1,yStart:yStart+yLength-1,1:end); %this way is correct to avoid inversions (10/25/2016). image-j will LOOK inverted but this is b/c of ydir
    %     stack = stackFull(xStart:xStart+xLength-1,yStart+yLength-1:-1:yStart,1:end); %changed 10/24/2016

        %Remember that X is columns in the transposed/final image (below), and Y is rows. 
        %07/22/2016: got rid of permutations. this will cause x and y to be
        %switched in Imaris (long axis will be X, short will be Y). will not
        %affect already converted files. lines 180-185, line 246
        %note the GUIs display the image non-transposed, opposite of the final
        %data. 

            if strcmp(regParameters.method,'MaxProjection')
    %             proj2D_mat(:,:,t) = max(stack,[],3)';
                  proj2D_mat(:,:,t) = max(stack,[],3);
            else
    %             proj2D_mat(:,:,t) = mean(stack(:,:,regParameters.planes),3)';
                  proj2D_mat(:,:,t) = mean(stack(:,:,regParameters.planes),3);
            end        
    end
    projectionTime=toc;

    tFormMat = [];
    parfor t=1:numStacks
        tic;
        disp(sprintf('Computing registration for stack %2.0f',t));
            if t==regParameters.fixedFrame
                tFormMat(:,:,t) = [1 0 0; 0 1 0; 0 0 1];
            else
                tForm_affine2D = imregtform(proj2D_mat(:,:,t), proj2D_mat(:,:,regParameters.fixedFrame), 'translation',...
                                             optimizer, metric);
                tFormMat(:,:,t) = tForm_affine2D.T;
            end
        regTime(t)=toc;
        disp(sprintf('Registration for stack %2.0f completed in %2.2f seconds',t,regTime(t)));
        end

    end

    if ~registerConcurrently
        regParameters=[];
        regParameters.fixedFrame=0;
        tFormMat = zeros(1,1,numStacks);
        regTime = 'Not Registered';
    end
    %%%%%%
    SAVEPATH = pwd;
    mkdir([SAVEPATH,fs,'processed']);
    tic;
    timeSeries_maxProj = zeros(crop(2),crop(4),stDim(3),'uint16');
    timeSeries_meanProj = double(timeSeries_maxProj);
    xStart=crop(1);
    yStart=crop(3);
    xLength=crop(2);
    yLength=crop(4);

    %%%option to write as .tiff

    fprintf('Converting files to %s format...',outputformat);
    fixedFrame=regParameters.fixedFrame;
    parfor t = 1:numStacks
        tic
        disp(['Submitting time point ' num2str(t, '%.4d') ' to a local worker.']);
    % %     processTimepoint(parameterDatabase, t, jobMemory(2));
    %     stack = multibandread(StackData(t).name, [stDim(2) stDim(1) stDim(3)], ...
    %         '*uint16', 0, 'bsq', 'ieee-le');

    % %see multibandread and keller's clusterPT.m for mor information crop is
    % %[left coordinate, widht, top coordinate, height]
    %     stack = multibandread(StackData(t).name, [stDim(2) stDim(1) stDim(3)], ...
    %         '*uint16', 0, 'bsq', 'ieee-le', ...
    %         {'Column', 'Range', [crop(1), 1, crop(1)+crop(2)-1]}, ...
    %         {'Row', 'Range', [crop(3), 1, crop(3) + crop(4)-1]});

        memMap = memmapfile(StackData(t).name,'Format','uint16');
        filedata = memMap.Data;

        stackFull = reshape(filedata,stDim); 
    %     stack = permute(stackFull(xStart:xStart+xLength-1,yStart:yStart+yLength-1,1:end),[2,1,3]);
        stack = stackFull(xStart:xStart+xLength-1,yStart:yStart+yLength-1,1:end); 
    %     stack = stackFull(xStart:xStart+xLength-1,yStart+yLength-1:-1:yStart,1:end); %produces L-R inversion
        stack(stack<intMask) = 0;

        if registerConcurrently && t~= fixedFrame;
    %         affineTFormObj = affine2d(tFormMat(:,:,t));
    %         stack=imwarp(stack,affineTFormObj);
%             stack=imtranslate(stack,round(tFormMat(3,1:2,t))); %don't allow sub-pixel translations
            stack=imtranslate(stack,tFormMat(3,1:2,t));
        end

        if computeTimeSeriesMaxProjection
            timeSeries_maxProj = max(timeSeries_maxProj,stack);
        end

        if computeTimeSeriesMeanProjection
            timeSeries_meanProj = timeSeries_meanProj + double(stack)./numStacks;
        end

        outputName = sprintf('%s%sprocessed%slsstack_t%04.0f%s',SAVEPATH,fs,fs,t,outputformat);
        writeImage(stack, outputName);
        looptime(t) = toc;
    end


    mkdir([SAVEPATH,fs,'timeProj']);
    timeAppend = datestr(clock,30);
    if computeTimeSeriesMaxProjection
        writeImage(timeSeries_maxProj,[SAVEPATH,fs,'timeProj',fs,'tS_maxproj',timeAppend,'.tif']); %write as tiff;
    end

    if computeTimeSeriesMeanProjection
        writeImage(uint16(timeSeries_meanProj),[SAVEPATH,fs,'timeProj',fs,'tS_meanProj',timeAppend,'.tif']); %write as tiff;
    end

    if writeKeyImage
        memMap = memmapfile(StackData(regParameters.fixedFrame).name,'Format','uint16');
        filedata = memMap.Data;
        stackFull = reshape(filedata,stDim); 

        writeImage(stackFull,[SAVEPATH,fs,'timeProj',fs,'tS_fixedFrame',sprintf('t%04.0f',regParameters.fixedFrame-1),'.tif']);
    end

    if isfield(convert,'writeTimeSliceMovies') && convert.writeTimeSliceMovies && computeTimeSeriesMaxProjection %Both must be true to write the time slice movies automatically in 8bit
        klbFiles = dir(['processed',fs,'*.klb*']);
        rescale_sclae = double( [min(timeSeries_maxProj(1:end)), max(timeSeries_maxProj(1:end))] );
        tiffNames = {};
        for k=1:numel(klbFiles)
            fileDat = readImage(['processed',fs,klbFiles(k).name]);
            rescaleDat = uint8( 255*[double(fileDat) - rescale_scale(1)] / diff(rescale_scale) );
        
            if k==numel(klbFiles)
                 tiffNames = GenerateSliceMovies(tiffNames,rescaleDat,['processed',fs,'tsView'],true);
            else
                 tiffNames = GenerateSliceMovies(tiffNames,rescaleDat,['processed',fs,'tsView'],false);
            end
            fprintf('Generated slice movie frame %04.0f...\n',k);
        end
        
    end
    
    disp('');
    zurgMessage = '@!ADEADSVFT~G@VGRE#T~!~DASFF@#T#%RQT$#!T$~!#$GQB GFSGFS REGF!#$QTG~$T$~GQEQGETG~$TG!';
    disp(zurgMessage(randperm(length(zurgMessage))));
    disp('we have finished, gluurg');

    conversionTime=toc;
    disp(sprintf('Average parallel read/write took each worker %2.2f s, total time converting was %2.2f s',mean(looptime),conversionTime));

    save conversionLog conversionTime projectionTime looptime regTime tFormMat cropParameters regParameters
%     save conversionLog conversionTime looptime regTime tFormMat cropParameters regParameters
    
end

% imagesc(max(timeSeries_maxProj,[],3)) %use this line to look at time series max projection
if system_shutdown_after_completion 
    system('shutdown -r'); %turns computer off after finishing
end
 