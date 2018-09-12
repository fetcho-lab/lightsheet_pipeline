Im = GetImaris;
segChannel = input('Please enter segmentation channel: ');

cData=Im.GetDataSet;
segVolume = ExtractVolume(cData,segChannel-1,0);
dim = size(segVolume);

cellDiameter_ScaleFactor = 1.0; %does not apply to z
zDiameter = 4;

removeOverlapping = true;

Sc = diag([cData.GetExtendMaxX/cData.GetSizeX;cData.GetExtendMaxY/cData.GetSizeY;...
           cData.GetExtendMaxZ/cData.GetSizeZ]);

br_threshold=100;%original value:120
cont_threshold=7;%original value:7
cell_rad=3;%original value: 5?

%%  set filters and matrices for detecting cells;

% info = imfinfo(fname);
% num_images = numel(info);
% dim=[info(1).Height,info(1).Width, num_images];

cell_rad = round( cell_rad/Sc(1,1) );

ave_rad=round(cell_rad/2)+1;
[avedisk,  ave_se, r1, c1, maskinds]=make_recog_disk(ave_rad,dim);
[maxdisk,  max_se, r2, c2, maxinds]=make_recog_disk(round(cell_rad*cellDiameter_ScaleFactor),dim);
onedisk=makeDisk(ave_rad,ave_rad*2+1);
one_se=strel(onedisk);

r=cell_rad*2;
dimp=[dim(1)+r*2 dim(2)+r*2];
oop=zeros(dimp);
oop(r+1:end-r,r+1:end-r)=1;
one_inds=find(oop);

[mdisk,  ~, ~, ~, rankinds]=make_recog_disk(r,dimp);
rank_ones=double(maskones2D_mex(int32([dim(1) dim(2)]),int32(mdisk),int32(size(mdisk))))';

%%
cell_info=struct;

% cell_color=zeros([dim(1) dim(2)*2+1 dim(3) 3],'uint8');
cellnum=0;
allmask=zeros(dim(1),dim(2));
imlen=dim(1)*dim(2);

for z = 1:size(segVolume,3)
    im=segVolume(:,:,z);
    allmask(:)=0;
    contimage = local_contrast_mex(single(im),int32(32),single(cont_threshold));
    contimage = imdilate(imerode(contimage,one_se),one_se);
    contimage = contimage.*uint8((im>br_threshold));

    candidates=find(contimage);
%round 1
    if ~isempty(candidates)
   

        imrank = calc_local_rank(im,rank_ones,cell_rad*2,oop,one_inds,rankinds,candidates);
        aveimg = double(local_average_mex(single(imrank),int32(c1),int32(r1),int32(candidates)));
        maximg = double(local_max_mex(single(aveimg),int32(c2),int32(r2),int32(candidates)));

        inds=find(maximg(candidates)>0 & aveimg(candidates) >0.4);
        mask2=zeros(dim(1),dim(2));

        for i=1:length(inds)
            cinds=candidates(inds(i))+maskinds;
            cinds(cinds > imlen | cinds<1)=[];
            mask2(cinds)=1;
        end

        allmask=mask2;

        %% recognizing cells in the second round            

        mask3=ones(size(im),'uint8')-imdilate(uint8(allmask),max_se);
        mask3 = imdilate(imerode(mask3,one_se),one_se);
        candidates2=candidates(mask3(candidates)>0);

        imrank2 = calc_local_rank(im,rank_ones,cell_rad*2,oop,one_inds,rankinds,candidates2);
        aveimg2 = double(local_average_mex(single(imrank2),int32(c1),int32(r1),int32(candidates2)));        
        maximg2 = double(local_max_mex(single(aveimg2),int32(c1),int32(r1),int32(candidates2)));

        inds=find(maximg2(candidates2)>0 & aveimg2(candidates2) >0.4);
        mask2=zeros(dim(1),dim(2));

        for i=1:length(inds)
            cinds=candidates2(inds(i))+maskinds;
            cinds(cinds > imlen | cinds<1)=[];
            mask2(cinds)=1;
        end

        allmask=allmask+mask2;

        %% create each cell ROIs

        [celllabel, totcell]=bwlabel(allmask,8);
        if totcell>0
                cell_info=create_cell_info(cell_info,celllabel, totcell,z);
        end
    else

        totcell=0;
        celllabel=zeros(size(im));
    end

%     cell_color(:,:,z,:)=reshape(make2DMask(im,celllabel,candidates),[dim(1) dim(2)*2+1 1 3]);

    cellnum=cellnum+totcell;    
    disp(num2str(z));
    
end

if removeOverlapping
%%Filter out cells that overlap in each slice choosing the brightest
%can add an option to save removed cells to different structure
    sliceLocations = vertcat(cell_info.slice);
    removeIndex = [];
    for z=1:size(segVolume,3)
        cells_in_slice = cell_info(sliceLocations==z);
        segSlice = segVolume(:,:,z);
        clear cellSliceDiameters;

        for k=1:numel(cells_in_slice)
            cellSliceDiameters(k,:) = [diff(cells_in_slice(k).x_minmax), diff(cells_in_slice(k).y_minmax)];
            cellIntValue(k) = mean(segSlice(cells_in_slice(k).inds));
        end

        if numel(cells_in_slice) > 0
            medianDiameter = sum( median(cellSliceDiameters,1) ) /2;    
            sliceDistanceMatrix = pdist2(vertcat(cells_in_slice.center),vertcat(cells_in_slice.center));
        end

        cell_in_slice_toRemove = [];
        for k=1:numel(cells_in_slice)
            cells2Close = sliceDistanceMatrix(k,:) < 0.5*medianDiameter*cellDiameter_ScaleFactor;
            cells2Close(k) = false; %exclude self
            cells2Check = find(cells2Close);

            for m=1:sum(cells2Close)
                if cellIntValue(k) > cellIntValue(cells2Check(m))
                    cell_in_slice_toRemove = [cell_in_slice_toRemove cells2Check(m)];
                else
                    cell_in_slice_toRemove = [cell_in_slice_toRemove k];
                end
            end
        end

        cell_in_slice_toRemove = unique(cell_in_slice_toRemove);
        sliceIndex = find(sliceLocations==z);
        removeIndex = [removeIndex sliceIndex(cell_in_slice_toRemove)];
    end
    
disp(sprintf('%4.0f overlapping cells were removed. ',numel(removeIndex)));
cell_info(removeIndex) = [];

end
%%Generate Imaris Spots
pxyz = zeros(cellnum,3+1);
celldiameters = zeros(cellnum,3);

for k=1:numel(cell_info)
    pxyz(k,1:3) = [cell_info(k).center*Sc(1,1) cell_info(k).slice*Sc(3,3)-Sc(3,3)/2 ];
    celldiameters(k,:) = [diff(cell_info(k).x_minmax)*Sc(1,1)*cellDiameter_ScaleFactor...
                          diff(cell_info(k).y_minmax)*Sc(1,1)*cellDiameter_ScaleFactor...
                          zDiameter];
end

sH = MakeImarisSpots(pxyz,[1,0,0,0],'autoSegment',Im);
sH.SetRadiiXYZ(celldiameters./2);

save autoSegmentData cell_info;