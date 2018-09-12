im=GetImaris;
cData=im.GetDataSet;

backTrackData = false;

spotsName = input('Please type the name of the Spots Objection to use: ','s');

colDim = cData.GetSizeX; rowDim=cData.GetSizeY; DimZ=cData.GetSizeZ;
micronExtentX = cData.GetExtendMaxX - cData.GetExtendMinX;
micronExtentY = cData.GetExtendMaxY - cData.GetExtendMinY;
micronExtentZ = cData.GetExtendMaxZ - cData.GetExtendMinZ;

volDimensions = [colDim rowDim DimZ];
Sc = diag([micronExtentX/colDim; micronExtentY/rowDim; micronExtentZ/DimZ]);
cSpots = CheckSpots(im);

CaSeg=cSpots{strcmp(cSpots(:,1),spotsName),2};

spPos = CaSeg.GetPositionsXYZ;

spPos(:,1) = spPos(:,1)-cData.GetExtendMinX;
spPos(:,2) = spPos(:,2)-cData.GetExtendMinY;
spPos(:,3) = spPos(:,3)-cData.GetExtendMinZ;

spRadiiXYZ = CaSeg.GetRadiiXYZ;

save imsSegmentationData spRadiiXYZ spPos Sc spotsName colDim rowDim DimZ

%backTrack approach to crosstrial regisration
% backTrackData = false;

if backTrackData
    [FILE,PATH] = uigetfile('.mat','Please select xF file...');
    load([PATH,FILE]);
    spPosKey = spPos;
    spRadiiKey = spRadiiXYZ;
    
    for k=1:size(TransformSeries,3)
        if isequal(TransformSeries(:,:,k),eye(4))
            xFKey(k) = true;
        else
            xFKey(k) = false;
        end
    end
    xFtoUse = zeros(size(TransformSeries,3),1);
%     xFtoUse(xFKey) = 1;
    
    disp('Transform: Key/NotKey');
    for k=1:length(xFKey)
        disp(sprintf('tF # %2.0f: %2.0f',k,xFKey(k)));
    end
    
    toSetTrue = input('Please pass an array selecting which transforms to utilize...: ');
    xFtoUse = toSetTrue;
    for k=1:length(xFtoUse)
            clear spPos; clear bkwd_correspondenceKey;
            
            fwd_xF = TransformSeries(:,:,xFtoUse(k));
            backPos = xformBackTrack(fwd_xF,spPosKey,Sc);
            backRadii = spRadiiKey;
            
            bkwd_correspondenceKey = [1:size(backPos,1)]'; %tells correspondence between cells in key dataset to transformed. 
            
            backPosPx = backPos*Sc^-1;
            pts_withinBounds = sum(backPosPx>0,2) & [ backPosPx(:,1) < colDim]...
                & [backPosPx(:,2) < rowDim]  & [backPosPx(:,3) < DimZ];
            backPos(~pts_withinBounds,:) = [];
            backRadii(~pts_withinBounds,:) = [];
            bkwd_correspondenceKey(~pts_withinBounds) = [];
            
            spPos = backPos;
            spRadiiXYZ = backRadii;
            
            save(sprintf('imsSegmentationData_crossTrial%02.0f',xFtoUse(k)),...
                'spRadiiXYZ', 'spPos', 'Sc', 'spotsName', 'colDim', 'rowDim', 'DimZ', 'bkwd_correspondenceKey', 'fwd_xF')
    end
end