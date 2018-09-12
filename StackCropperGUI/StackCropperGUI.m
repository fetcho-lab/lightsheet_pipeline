function varargout = StackCropperGUI(varargin)
% STACKCROPPERGUI MATLAB code for StackCropperGUI.fig
%      STACKCROPPERGUI, by itself, creates a new STACKCROPPERGUI or raises the existing
%      singleton*.
%
%      H = STACKCROPPERGUI returns the handle to a new STACKCROPPERGUI or the handle to
%      the existing singleton*.
%
%      STACKCROPPERGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in STACKCROPPERGUI.M with the given input arguments.
%
%      STACKCROPPERGUI('Property','Value',...) creates a new STACKCROPPERGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before StackCropperGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to StackCropperGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help StackCropperGUI

% Last Modified by GUIDE v2.5 23-Jun-2016 14:57:15

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @StackCropperGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @StackCropperGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before StackCropperGUI is made visible.
function StackCropperGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to StackCropperGUI (see VARARGIN)

% Choose default command line output for StackCropperGUI
% set(gcf,'toolbar','figure');

handles.output = hObject;
handles.image = varargin{1};
handles.stDim = size(handles.image);

nonMask = handles.image(1:end);
nonMask(nonMask==0) = [];

logData = log(double(nonMask)); %just in case data was masked previously
% logData = log(double(handles.image(1:end))); 

[log16,logBins] = hist(logData,100);
cF = cumsum(log16)/sum(log16);
cFidx = find(cF > 0.99);
initialCMx = exp(logBins(cFidx(1)));

set(handles.caxis_max,'String',sprintf('%2.0f',initialCMx));

hold(handles.axes1,'on');
handles.mskScreen = imshow(cat(3,zeros(size(handles.image)),zeros(size(handles.image)),ones(size(handles.image))),'parent',handles.axes1);
handles.maskedPixels = zeros(size(handles.image));

handles.imgHandle=imshow(handles.image,'parent',handles.axes1);
hold(handles.axes1,'off');
caxis(handles.axes1,[0,initialCMx]);

handles.redBox = [0.2*size(handles.image,2) 0.6*size(handles.image,2), 1, size(handles.image,1)]; %


axis(handles.axes1,'equal');
axis(handles.axes1,'tight');
set(handles.imgHandle,'ButtonDownFcn',@axes1_ButtonDownFcn);

handles.redBoxLine=plotSquare(handles.axes1,handles.redBox,[1 0 0]);
% [hist16,histbins] = hist(double(handles.image(1:end)),50);
% handles.histBins = histbins;
bar(handles.axes2,logBins,log16); 
xTicks = get(handles.axes2,'XTick');
xLogTick_decade = linspace(xTicks(1),xTicks(end),10);
for j=1:10
    xIntLabel{j} = sprintf('%2.0f',exp(xLogTick_decade(j) ) );
end
set(handles.axes2,'XTick',xLogTick_decade,'XTickLabel',xIntLabel);
xlabel(handles.axes2,'16bit intensity');
ylabel(handles.axes2,'pixel count');
handles.histBins = logBins;

shading flat;

yLim=get(handles.axes2,'ylim');
hold(handles.axes2,'on');
handles.threshline=plot(handles.axes2,[handles.histBins(1) handles.histBins(1)],yLim,'r','linewidth',2');
hold(handles.axes2,'off');
handles.maskLvl = exp(handles.histBins(10));
% Populate the listbox
handles=load_listbox(pwd,handles);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes StackCropperGUI wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = StackCropperGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
handles=guidata(hObject);
varargout{1} = round(handles.redBox);
varargout{2} = handles.maskLvl;
delete(handles.figure1);

% --- Executes on button press in AcceptButton.
function AcceptButton_Callback(hObject, eventdata, handles)
% hObject    handle to AcceptButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close(handles.figure1);

%------

function BoxLine=plotSquare(axes,boundingBox,color)
hold(axes,'on');
% plot(axes,boundingBox(1:2),repmat(boundingBox(4),1,2),'color',color,'linewidth',2);
% plot(axes,boundingBox(1:2), repmat(boundingBox(3),1,2),'color',color,'linewidth',2);
% plot(axes,repmat(boundingBox(1),1,2),boundingBox(3:4),'color',color,'linewidth',2);
% plot(axes,repmat(boundingBox(2),1,2),boundingBox(3:4),'color',color,'linewidth',2);

xA=boundingBox(1); xB=boundingBox(1)+boundingBox(2)-1; xC=boundingBox(1)+boundingBox(2)-1; xD=boundingBox(1);
yA=boundingBox(3); yB=boundingBox(3); yC=boundingBox(3)+boundingBox(4)-1; yD=boundingBox(3)+boundingBox(4)-1;
BoxLine = plot([xA,xB,xC,xD,xA],[yA,yB,yC,yD,yA],'color',color,'linewidth',2);
hold(axes,'off');

function boxBounds=checkDimensions(cropSelection,imgWidth,imgHeight)
%checks that the edges of the crop are within the image
boxBounds = cropSelection;
if boxBounds(1) < 1
    boxBounds(1) = 1;
end
if boxBounds(1) + boxBounds(2) - 1 > imgWidth
    boxBounds(2) = imgWidth-boxBounds(1)+1;
end
if cropSelection(3) < 1
    boxBounds(3) = 1;
end
if cropSelection(3)+cropSelection(4) -1 > imgHeight
    boxBounds(4) = imgHeight-boxBounds(3)+1;
end


% --- Executes on mouse press over axes background.
function axes1_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to axes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);
location=get(handles.axes1,'currentpoint');
X=location(1,1); Y=location(1,2);

boxWidth = handles.redBox(2);
boxHeight = handles.redBox(4);

handles.redBox(1:2) = [X - boxWidth/2, boxWidth];
handles.redBox(3:4) = [Y - boxHeight/2, boxHeight];
try 
    delete(handles.redBoxLine);
end
handles.redBox = checkDimensions(handles.redBox,size(handles.image,2),size(handles.image,1));
handles.redBoxLine=plotSquare(handles.axes1,handles.redBox,[1,0,0]);

guidata(hObject,handles);


% --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);
boxWidth = handles.redBox(2);
boxHeight = handles.redBox(4);
boxCenterX = handles.redBox(1) + boxWidth/2;
boxCenterY = handles.redBox(3) + boxHeight/2;
scalefactor = str2num(get(handles.rbox_scale_value,'String'));
incr = 1+scalefactor/100;
decr = 1-scalefactor/100;

switch eventdata.Character
    case '+'
        handles.redBox = [boxCenterX-boxWidth*incr/2 boxWidth*incr ...
                          boxCenterY-boxHeight*incr/2 boxHeight*incr];       
    case '-'
        handles.redBox = [boxCenterX-boxWidth*decr/2 boxWidth*decr ...
                          boxCenterY-boxHeight*decr/2 boxHeight*decr];
    case 'W'
        handles.redBox(1:2) = [boxCenterX-boxWidth*incr/2 boxWidth*incr];
        
    case 'w'
        handles.redBox(1:2) = [boxCenterX-boxWidth*decr/2 boxWidth*decr];
       
    case 'H'
        handles.redBox(3:4) = [boxCenterY-boxHeight*incr/2 boxHeight*incr];  
        
    case 'h'
        handles.redBox(3:4) = [boxCenterY-boxHeight*decr/2 boxHeight*decr];
        
    case 'C'
        imgCx = size(handles.image,2)/2;
        imgCy = size(handles.image,1)/2;
        handles.redBox = [imgCx-boxWidth/2 boxWidth ...
                          imgCy-boxHeight/2 boxHeight];
end

switch eventdata.Key
    case 'uparrow'
        handles.redBox(3) = handles.redBox(3)-(scalefactor/100)*size(handles.image,1);
    case 'downarrow'
        handles.redBox(3) = handles.redBox(3)+(scalefactor/100)*size(handles.image,1);
    case 'leftarrow'
        handles.redBox(1) = handles.redBox(1)-(scalefactor/100)*size(handles.image,2);
    case 'rightarrow'
        handles.redBox(1) = handles.redBox(1)+(scalefactor/100)*size(handles.image,2);
end

try
    delete(handles.redBoxLine);
end
handles.redBox = checkDimensions(handles.redBox,size(handles.image,2),size(handles.image,1));
handles.redBoxLine = plotSquare(handles.axes1,handles.redBox,[1,0,0]);
guidata(hObject,handles);


% --- Executes on button press in evaluate1.
function evaluate1_Callback(hObject, eventdata, handles)
% hObject    handle to evaluate1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);
% pixelEdges(3:4) = round([size(handles.image,2)-handles.redBox(4), size(handles.image,2)-handles.redBox(3)]); %deal with the image inversion in imagesc
% pixelEdges(1:2) = round(handles.redBox(1:2));
pixelEdges = round(handles.redBox);
subsetImg_bg = handles.image(pixelEdges(3)+1:pixelEdges(4),pixelEdges(1)+1:pixelEdges(2));

meanBG = mean(double(subsetImg_bg(1:end)));
stdBG = std(double(subsetImg_bg(1:end)));

maskLevl = meanBG+3*stdBG;

[hist16,histbins] = hist(double(handles.image(1:end)),50);
bar(handles.axes2,histbins,hist16); 
shading flat;

hold(handles.axes2,'on');
yLim = get(handles.axes2,'YLim');
plot(handles.axes2,[maskLevl,maskLevl],yLim,'r','linewidth',2');
hold(handles.axes2,'off');

% figure(2);
% imagesc(subsetImg_bg); colormap gray
% set(gca,'ydir','normal');

guidata(hObject,handles);


% --- Executes on mouse press over axes background.
function axes2_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to axes2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);
disp('axes 2 press');
location=get(handles.axes2,'currentpoint');
handles.maskLevel = round(location(1,1));
try
    delete(handles.threshLine);
end
yLim = get(handles.axes2,'YLim');

hold(handles.axes2,'on');
handles.threshline=plot(handles.axes2,[threshLine,threshLine],yLim,'r','linewidth',2');
hold(handles.axes2,'on');

guidata(hObject,handles);


% --- Executes on slider movement.
function slider2_Callback(hObject, eventdata, handles)
% hObject    handle to slider2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);
mVal=get(hObject,'Value');
maskLevel = round(mVal * (length(handles.histBins)-1) )+1;

try
    delete(handles.threshline);
end

yLim = get(handles.axes2,'YLim');

hold(handles.axes2,'on');
handles.threshline=plot(handles.axes2,[handles.histBins(maskLevel) handles.histBins(maskLevel)],yLim,'r','linewidth',2');
hold(handles.axes2,'off');

handles.maskLvl = round( exp(handles.histBins(maskLevel)) );
handles.maskedPixels = handles.image < handles.maskLvl ;

guidata(hObject,handles);
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function caxis_max_Callback(hObject, eventdata, handles)
% hObject    handle to caxis_max (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of caxis_max as text
%        str2double(get(hObject,'String')) returns contents of caxis_max as a double


% --- Executes during object creation, after setting all properties.
function caxis_max_CreateFcn(hObject, eventdata, handles)
% hObject    handle to caxis_max (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in caxis_scale_button.
function caxis_scale_button_Callback(hObject, eventdata, handles)
% hObject    handle to caxis_scale_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);
newMax = get(handles.caxis_max,'String');
caxis(handles.axes1,[0 str2num(newMax)]);
guidata(hObject,handles);



function rbox_scale_value_Callback(hObject, eventdata, handles)
% hObject    handle to rbox_scale_value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of rbox_scale_value as text
%        str2double(get(hObject,'String')) returns contents of rbox_scale_value as a double


% --- Executes during object creation, after setting all properties.
function rbox_scale_value_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rbox_scale_value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in evalMask.
function evalMask_Callback(hObject, eventdata, handles)
% hObject    handle to evalMask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%see http://blogs.mathworks.com/steve/2009/02/18/image-overlay-using-transparency/
handles=guidata(hObject);
toggleState = get(hObject,'Value');
if toggleState
    set(handles.imgHandle,'AlphaData', ~handles.maskedPixels);
else
    set(handles.imgHandle,'AlphaData',1);
end
guidata(hObject,handles);
% Hint: get(hObject,'Value') returns toggle state of evalMask


% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles=guidata(hObject);
contents = cellstr(get(hObject,'String'));
selection=contents{get(hObject,'Value')};
[path,filename,ext] = fileparts(selection);
isdir = handles.is_dir(get(hObject,'value'));

if isdir
    cd(selection);
    handles=load_listbox(pwd,handles);
elseif strcmp(ext,'.stack')
%     fullstack = multibandread(selection, [size(handles.image,2) size(handles.image,1) 1], ...
%                               '*uint16', 0, 'bsq', 'ieee-le');
%     handles.image = max(fullstack,[],3);
    disp('loading stack....');

    memMap = memmapfile(selection,'Format','uint16');
    filedata = memMap.Data;
    
    stack = reshape(filedata,[ handles.stDim(2), handles.stDim(1), numel(filedata)/prod(handles.stDim(1:2)) ] );
    size(handles.image);
    handles.image = max(stack,[],3)';

    try
        delete(handles.imgHandle);
        delete(handles.redboxLine);
    end
   
   cla(handles.axes1);
   hold(handles.axes1,'on');
   handles.mskScreen = imshow(cat(3,zeros(size(handles.image)),zeros(size(handles.image)),ones(size(handles.image))),'parent',handles.axes1);
   handles.imgHandle = imshow(handles.image,'parent',handles.axes1);
   handles.redboxLine = plotSquare(handles.axes1,handles.redBox,[1 0 0]);
   hold(handles.axes1,'off');
   cScale = get(handles.caxis_max,'String');
   caxis(handles.axes1,[0,str2num(cScale)]);
   
   handles.maskedPixels = handles.image < handles.maskLvl;
   
   if get(handles.evalMask,'Value')
       set(handles.imgHandle,'AlphaData', ~handles.maskedPixels);
   end
   
   disp(sprintf('loaded %s',selection));
end
guidata(hObject,handles);
% Hints: contents = cellstr(get(hObject,'String')) returns listbox1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox1


% --- Executes during object creation, after setting all properties.
function listbox1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function handles=load_listbox(dir_path, handles)

cd (dir_path)
% dir_struct = dir([dir_path '\*STACK']);
dir_struct = dir(dir_path);
[sorted_names,sorted_index] = sortrows({dir_struct.name}');
handles.file_names = sorted_names;
handles.is_dir = [dir_struct.isdir];
handles.sorted_index = sorted_index;
set(handles.listbox1,'String',handles.file_names,...
    'Value',1)


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
if isequal(get(hObject, 'waitstatus'), 'waiting')
    uiresume(hObject)
else
    delete(hObject)
end


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes during object creation, after setting all properties.
function axes1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate axes1
