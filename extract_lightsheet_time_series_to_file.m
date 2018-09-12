clear all; close all;
%SPOTS USED FOR SEGMENTATION MUST HAVE THE NAME: tsMaxCellSegmentation
%currently is saving mean intensity of ellipsoid
% writeExcel = false;
useExcelFile = false; %if true will use excel file as source of segmented neurons, else will use a .mat file
% useExcelFile = true;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs=filesep;
[PATH_processed] = uigetdir(pwd, 'select processed data directory');

fte=-1;
while fte~=1 && fte ~=2
    fte = input('Enter 1 to select .klb or 2 for .tif: ');
end

cd(PATH_processed);
if fte==1
    datafiles = dir('*.klb');
else
    datafiles = dir('*.tif');
end

disp('files are in this order: ');
disp(vertcat(datafiles.name));
disp('Press enter to continue...');
pause;


if ~useExcelFile
    [segmentFILE,PATH] = uigetfile('*.mat', 'select segmented data file'); 
    %generate this from Imaris using imSegmentation2matfile.m
    disp('Starting read...');
    load([PATH,segmentFILE]);
%     [FILE,PATH] = uigetfile('*ims', 'select segmented max projection');
%     im=GetImaris;
% 
% 
%     im.FileOpen(strcat(PATH,fs,FILE),'');
%     cData=im.GetDataSet;
% 
%     colDim = cData.GetSizeX; rowDim=cData.GetSizeY; DimZ=cData.GetSizeZ;
%     micronExtentX = cData.GetExtendMaxX - cData.GetExtendMinX;
%     micronExtentY = cData.GetExtendMaxY - cData.GetExtendMinY;
%     micronExtentZ = cData.GetExtendMaxZ - cData.GetExtendMinZ;
% 
%     volDimensions = [colDim rowDim DimZ];
%     Sc = diag([micronExtentX/colDim; micronExtentY/rowDim; micronExtentZ/DimZ]);
%     cSpots = CheckSpots(im);
% 
%     CaSeg=cSpots{strcmp(cSpots(:,1),'tsMaxCellSegmentation'),2};
% 
%     spPos = CaSeg.GetPositionsXYZ;
%     
%     spPos(:,1) = spPos(:,1)-cData.GetExtendMinX;
%     spPos(:,2) = spPos(:,2)-cData.GetExtendMinY;
%     spPos(:,3) = spPos(:,3)-cData.GetExtendMinZ;
%     
%     spRadiiXYZ = CaSeg.GetRadiiXYZ;
else
    [xmlFile,xmlPath] = uigetfile('.xml', 'select ch0.xml meta data');
    disp('Starting read...');
    [dimensions, voxelScale] = readCh0xml(xmlPath);
%     colDim=dimensions(1); rowDim=dimensions(2); DimZ=dimensions(3);
%     xyScale = input('Please enter microns per voxel in xy: ');
%     zScale = input('Please enter microns per voxel in z: ');
    Sc = diag(voxelScale);
    
    [segmentFILE,PATH] = uigetfile('*.xls*', 'select exported positions and radii excel file');
    cd(PATH);
    
    xlsPosition = xlsread(segmentFILE,'Position');
    spPos = xlsPosition(:,1:3);
    xls_spRadiiXYZ = xlsread(segmentFILE, 'Diameter');
    spRadiiXYZ = xls_spRadiiXYZ(:,1:3)/2; %DUH diameter is 2x radius
    
    maxPosition = max(spPos,[],1);
    maxPositionPixels = maxPosition*Sc^-1;
    
    try
        load([xmlPath,fs,'conversionLog.mat']);
    catch
        error('conversionLog.mat must be present in ch0.xml directory!');
    end

    colDim = cropParameters.crop(4);
    rowDim = cropParameters.crop(2);
    DimZ = dimensions(3);
    
    if sum(maxPositionPixels > [colDim, rowDim, DimZ])
        error('Spot positions exceed volume; check your Imaris max projection volume coordinates min and max (min must be 0)');
    end
end


maxEnclosure = max(spRadiiXYZ,[],1);
mxEnclPix = ceil(maxEnclosure./diag(Sc)'); %maximal half-width in each dimension for ellipses

% [dY,dX,dZ] = meshgrid(0:rowDim-1,0:colDim-1,0:DimZ-1);
[dX,dY,dZ] = meshgrid(0:colDim-1,0:rowDim-1,0:DimZ-1); %switched 07/22/2016
vdX = dX*Sc(1,1)+Sc(1,1)/2; %convert each pixel on the meshgrid to a voxel center point
vdY = dY*Sc(2,2)+Sc(2,2)/2;
vdZ = dZ*Sc(3,3)+Sc(3,3)/2;

%reshape coordinate list to nx3
% totalVoxels = colDim*rowDim*DimZ;
% dGrid = [reshape(vdX,totalVoxels,1), reshape(vdY,totalVoxels,1), reshape(vdZ,totalVoxels,1)];

%compute for each point the included voxels
sample_box_dims =2*mxEnclPix+2*[2,2,1]; %include a buffer in pixel-space
cellSegmentation = struct;

for j=1:size(spPos,1)
    
    %subscripts in x,y,z to volume - 1 (0-indexed)
    aPOffX = round(spPos(j,1)/Sc(1,1) - sample_box_dims(1)/2):round(spPos(j,1)/Sc(1,1) + sample_box_dims(1)/2); aPOffX(aPOffX<0) = []; aPOffX(aPOffX>colDim-1) = [];
    aPOffY = round(spPos(j,2)/Sc(2,2) - sample_box_dims(2)/2):round(spPos(j,2)/Sc(2,2) + sample_box_dims(2)/2); aPOffY(aPOffY<0) = []; aPOffY(aPOffY>rowDim-1) = [];
    aPOffZ = round(spPos(j,3)/Sc(3,3) - sample_box_dims(3)/2):round(spPos(j,3)/Sc(3,3) + sample_box_dims(3)/2); aPOffZ(aPOffZ<0) = []; aPOffZ(aPOffZ>DimZ-1) = [];
    
    total_elements_n = numel(aPOffX) * numel(aPOffY) * numel(aPOffZ);
    
%     subIndxX = dX(aPOffX+1,aPOffY+1,aPOffZ+1)+1; subIndxY = dY(aPOffX+1,aPOffY+1,aPOffZ+1)+1; subIndxZ = dZ(aPOffX+1,aPOffY+1,aPOffZ+1)+1; 
    subIndxX = dX(aPOffY+1,aPOffX+1,aPOffZ+1)+1; subIndxY = dY(aPOffY+1,aPOffX+1,aPOffZ+1)+1; subIndxZ = dZ(aPOffY+1,aPOffX+1,aPOffZ+1)+1; 
    %dimension-space is 0 indexed (aPOffX), but index space is 1-indexed
    %(subIndxX and when indexing into dimension space); tricky: X is columns, Y is
    %rows
    
    %linear index to above subscripts
  %  linear_idx = sub2ind([colDim,rowDim,DimZ], reshape(subIndxX,total_elements_n,1),...
%                                              reshape(subIndxY,total_elements_n,1),...
%                                            reshape(subIndxZ,total_elements_n,1));
  %above version incorrect as it causes a transpose in the indics 1 and 2
  %resulting in a permute to correct (corrected) on line 155
  linear_idx = sub2ind([rowDim,colDim,DimZ], reshape(subIndxY,total_elements_n,1),...
                                           reshape(subIndxX,total_elements_n,1),...
                                           reshape(subIndxZ,total_elements_n,1));
    
    %coordinates for each linearly indexed voxel
    subVol_voxel_centers = [vdX(linear_idx),vdY(linear_idx),vdZ(linear_idx)];
    x_xc = zeros(size(subVol_voxel_centers));
    
    for k=1:3
        x_xc(:,k) = subVol_voxel_centers(:,k)-spPos(j,k);
    end
    
    ell = diag(spRadiiXYZ(j,:).^2,0)^-1;
    
    dist2Ellipse = sum([x_xc*ell] .* x_xc,2);
    enclosed_solution = dist2Ellipse < 1;
    nPixels = sum(enclosed_solution);
    visualization = reshape(enclosed_solution,numel(aPOffY),numel(aPOffX),numel(aPOffZ));
    pxList = linear_idx(enclosed_solution);
    
    cellSegmentation(j).pixels = pxList;
    cellSegmentation(j).subMask = visualization;
    cellSegmentation(j).numPixels = nPixels;
end

%now, extract intensity mean of each spot over time
% fte=-1;
% while fte~=1 && fte ~=2
%     fte = input('Enter 1 to select .klb or 2 for .tif: ');
% end

cd(PATH_processed)

% if fte==1
%     datafiles = dir('*.klb');
% else
%     datafiles = dir('*.tif');
% end
% 
% disp('files are in this order: ');
% disp(vertcat(datafiles.name));
% disp('Press enter to continue...');
% pause;

fluorescence_time_series = zeros(numel(cellSegmentation),numel(datafiles));

tic
parfor m=1:numel(datafiles)
    disp(sprintf('Reading data file %s...',datafiles(m).name));
    timepointm = zeros(numel(cellSegmentation),1);
%     stackdata = permute(readImage(datafiles(m).name),[2,1,3]);
    stackdata = readImage(datafiles(m).name);
    for k=1:numel(cellSegmentation)
        timepointm(k) = sum(stackdata(cellSegmentation(k).pixels))/cellSegmentation(k).numPixels;
    end
    fluorescence_time_series(:,m) = timepointm;
end
parallel_read_time=toc;
disp(sprintf('Read time was %3.2f seconds',parallel_read_time));

extractParams.segmentation_file = segmentFILE;
extractParams.rowDim = rowDim;
extractParams.colDim = colDim;
extractParams.zDim = DimZ;

save ls_fluorescence_time_series fluorescence_time_series cellSegmentation spPos spRadiiXYZ Sc extractParams;

% if writeExcel
%     successfulWrite=false;
%     while ~successfulWrite
%         try
%         xlswrite('ls_fluorescence_time_series.xlsx',{'Spot ID';'Time'},1,'A1:A2');
%         successfulWrite=true;
%         catch
%             disp('Close ls_fluorescence_time_series.xlsx first! Press enter when ready...');
%             pause;
%         end
%         pause(5);
%     end
%     xlswrite('ls_fluorescence_time_series.xlsx',[0:numel(cellSegmentation)-1],1,'B1');
%     xlswrite('ls_fluorescence_time_series.xlsx',[2:numel(datafiles)]',1,'A3');
%    1 xlswrite('ls_fluorescence_time_series.xlsx',fluorescence_time_series',1,'B2');
% end