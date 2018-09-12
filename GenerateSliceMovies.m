function tiffName = GenerateSliceMovies(tiffName,Stack2Add,StoreDirectory,fileClose)
%tiffName = GenerateSliceMovies(tiffName,Stack2Add,StoreDirectory,fileClose)
% For each call of the function, adds a slice movie frame to each slice in
% the stack. If tiffName is empty, will overwrite all existing slice
% movies. StoreDirectory (traditionally processed/tsView) is where the
% slice movies are written and if fileClose is true (as it should be on the
% last iteration), will close the file and writeDirectory. 

if ~exist(StoreDirectory,'dir')
    mkdir(StoreDirectory);
end

fs=filesep;

if isempty(tiffName)
    
    for z=1:size(Stack2Add,3)
        
        stackName = [StoreDirectory,fs,sprintf('ts%03d',z)];
        tiffName{z} = [stackName,'.tif'];

        if exist(tiffName{z},'file');
           delete(tiffName{z});
        end

    %     tiffObj{z} = Tiff(tiffName,'a');

    end
end

%Add 1 stack per function call
if isa(Stack2Add,'uint8')
    BitsPerSample = 8;
elseif isa(Stack2Add,'uint16')
    BitsPerSample = 16; 
end


for m=1:size(Stack2Add,3)
%         objt = tiffObj{m};

    tiffObj = Tiff(tiffName{m},'a');

    tiffObj.setTag('Photometric',Tiff.Photometric.LinearRaw);
    tiffObj.setTag('BitsPerSample',BitsPerSample);
    tiffObj.setTag('ImageWidth',size(Stack2Add,2));
    tiffObj.setTag('ImageLength',size(Stack2Add,1));
    tiffObj.setTag('SamplesPerPixel',1);
    tiffObj.setTag('Compression',Tiff.Compression.PackBits);
    tiffObj.setTag('PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);

    tiffObj.write( Stack2Add(:,:,m) );        

end

if fileClose
    writeDirectory(tiffObj);
    tiffObj.close();
end

% disp(sprintf('Processed frame %03d',t));






