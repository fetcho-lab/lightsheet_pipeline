%klbFile time projection
BATCH = true;
RESTART = true;

correct_int16 = true;


if ~BATCH
    [PATH] = uigetdir(pwd, 'select .klb directory');
    cd(PATH)
    DirectoryList = {PATH};
else
    DirectoryList = {'F:\Dawnis\Jul12_6dpf\L09\_20170712_135520_Trial02\registered'...
                     'F:\Dawnis\Jul12_6dpf\L09\_20170712_142650\processed'...
                     'F:\Dawnis\Jul12_6dpf\L10\_20170712_165301\registered'...
                     'E:\Dawnis\L10_Continued\_20170712_170857ShockHB\registered'...
                     'E:\Dawnis\L10_Continued\_20170712_173942ShockSC\registered' ...
                     
        };
    
end

computeTimeSeriesMaxProjection = true;
computeTimeSeriesMeanProjection = true;


for dl = 1:numel(DirectoryList)
    cd(DirectoryList{dl});
    tic

    StackData = dir('lsstack*.klb'); %list all .klb files in the directory
    numCores = feature('numcores');

    img0 = readImage(StackData(1).name,numCores);

    timeSeries_maxProj = zeros(size(img0),'uint16');
    timeSeries_meanProj = double(timeSeries_maxProj);

    parfor t=1:numel(StackData)
        stack = readImage(StackData(t).name,numCores);
        disp(sprintf('Processing stack %4.0f...',t));
        if computeTimeSeriesMaxProjection
            timeSeries_maxProj = max(timeSeries_maxProj,uint16(stack));
        end

        if computeTimeSeriesMeanProjection
            timeSeries_meanProj = timeSeries_meanProj + double(stack)./numel(StackData);
        end
        
        if correct_int16 && isa(stack,'int16') %in case an int16 accidentally got written
            if ~exist('Corrected_int16','dir');
                mkdir('Corrected_int16');
            end
            
            movefile(StackData(t).name,['Corrected_int16\',StackData(t).name]);
            writeImage(uint16(stack),StackData(t).name);
        end
    end
    % for t=1:numel(StackData)
    %     stack = readImage(StackData(t).name,numCores);
    %     
    %     if t==1
    %         maxTimeProjection = stack;
    %     else
    %         maxTimeProjection = max(cat(4,maxTimeProjection,stack),[],4);
    %         disp(sprintf('Comparing time point %2.0f',t));
    %     end
    %     
    % 
    % end


    if computeTimeSeriesMaxProjection
        writeImage(uint16(timeSeries_maxProj),'klbMaxProjection.tif');
    end

    if computeTimeSeriesMeanProjection
        writeImage(uint16(timeSeries_meanProj),'klbMeanProjection.tif');
    end

    toc
end

if RESTART
    system('shutdown -r'); %turns computer off after finishing    
end