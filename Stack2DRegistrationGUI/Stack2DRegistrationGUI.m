function varargout = Stack2DRegistrationGUI(varargin)
% STACK2DREGISTRATIONGUI MATLAB code for Stack2DRegistrationGUI.fig
%      STACK2DREGISTRATIONGUI, by itself, creates a new STACK2DREGISTRATIONGUI or raises the existing
%      singleton*.
%
%      H = STACK2DREGISTRATIONGUI returns the handle to a new STACK2DREGISTRATIONGUI or the handle to
%      the existing singleton*.
%
%      STACK2DREGISTRATIONGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in STACK2DREGISTRATIONGUI.M with the given input arguments.
%
%      STACK2DREGISTRATIONGUI('Property','Value',...) creates a new STACK2DREGISTRATIONGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Stack2DRegistrationGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Stack2DRegistrationGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Stack2DRegistrationGUI

% Last Modified by GUIDE v2.5 30-May-2016 17:14:01

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Stack2DRegistrationGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @Stack2DRegistrationGUI_OutputFcn, ...
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


% --- Executes just before Stack2DRegistrationGUI is made visible.
function Stack2DRegistrationGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Stack2DRegistrationGUI (see VARARGIN)

% Choose default command line output for Stack2DRegistrationGUI

set(gcf,'toolbar','figure');

handles.output = hObject;

handles.image = varargin{1}; %first argument is fixed stack (MIDPOINT) see line 61
handles.stDim = size(handles.image);
handles.keyFrame = handles.image; %keep copy of reg. reference frame;
handles.stackPath = varargin{2};
handles.optimizer = varargin{3}; %matlab optimizer object
handles.metric = varargin{4}; %matlab optimizer metric object

handles.flattenMethod='MaxProject';

fs=filesep;

handles.stackFiles = dir([handles.stackPath,fs,'*stack']);
midPoint = floor(numel(handles.stackFiles)/2);

set(handles.fixedStack,'String',midPoint);
set(handles.currStack,'String',midPoint);

nonMask = handles.image(1:end);
nonMask(nonMask==0) = [];

logData = log(double(nonMask));
[log16,logBins] = hist(logData,100);
cF = cumsum(log16)/sum(log16);
cFidx = find(cF > 0.99);
initialCMx = exp(logBins(cFidx(1)));

hold(handles.axes2,'on');
handles.imgHandle=imshow(handles.image,'parent',handles.axes2);
caxis(handles.axes2,[0,initialCMx]);
handles.cLimMax = initialCMx;

% handles.yellowBox = [size(handles.image,2)/2 500, size(handles.image,1)/2, 500]; %
size_initial = round(0.20*size(handles.keyFrame));
handles.yellowBox = [25 size_initial(1) 25 size_initial(2)]; %
handles.yellowBoxLine=plotSquare(handles.axes2,handles.yellowBox,[1 1 0]);
handles.yBoxOffsets = zeros(numel(handles.stackFiles),2); %for frames where key region is too far outside of other yellow box

hold(handles.axes2,'off');


axis(handles.axes2,'equal');
axis(handles.axes2,'tight');


%default preview is just the box region for midpoint (reference) on left
%side
cropSelect = round(handles.yellowBox);
handles.fxRegion = handles.keyFrame(cropSelect(3):cropSelect(3)+cropSelect(4)-1,...
                                    cropSelect(1):cropSelect(1)+cropSelect(2)-1);
handles.mvRegion=zeros(size(handles.fxRegion));
handles.previewImage = imshow([handles.fxRegion zeros(size(handles.fxRegion))],'parent',handles.axes3);
axis(handles.axes3,'equal');
handles.registerImage = imshow([zeros(size(handles.fxRegion)) zeros(size(handles.fxRegion))],'parent',handles.axes1);
axis(handles.axes1,'equal');
caxis(handles.axes3,[0,handles.cLimMax]);
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Stack2DRegistrationGUI wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = Stack2DRegistrationGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
handles=guidata(hObject);
varargout{1}.cropRegion = round(handles.yellowBox);
varargout{1}.fixedFrame = str2num(get(handles.fixedStack,'String'));
varargout{1}.cropOffsets = handles.yBoxOffsets;

if strcmp(handles.flattenMethod,'MaxProject')
    varargout{1}.method='MaxProjection';
else
    varargout{1}.method='Selected Planes';
    varargout{1}.planes = str2num(get(handles.planes2average,'String'));
end
delete(handles.figure1);



function fixedStack_Callback(hObject, eventdata, handles)
% hObject    handle to fixedStack (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of fixedStack as text
%        str2double(get(hObject,'String')) returns contents of fixedStack as a double
handles=guidata(hObject);
newKeyNum = str2num(get(hObject,'String'));
handles.keyFrame = load2DProjection(handles,newKeyNum);
cropSelect = round(handles.yellowBox);
handles.fxRegion = handles.keyFrame(cropSelect(3):cropSelect(3)+cropSelect(4)-1,...
                                    cropSelect(1):cropSelect(1)+cropSelect(2)-1);
try
    clear(handles.previewImage)
end
handles.previewImage = imshow([handles.fxRegion handles.mvRegion],'parent',handles.axes3);
caxis(handles.axes3,[0,handles.cLimMax]);

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function fixedStack_CreateFcn(hObject, eventdata, handles)
% hObject    handle to fixedStack (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in testRegistration.
function testRegistration_Callback(hObject, eventdata, handles)
% hObject    handle to testRegistration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);
cropSelect = round(handles.yellowBox);
handles.fxRegion = handles.keyFrame(cropSelect(3):cropSelect(3)+cropSelect(4)-1,...
                                    cropSelect(1):cropSelect(1)+cropSelect(2)-1);
handles.mvRegion = handles.image(cropSelect(3):cropSelect(3)+cropSelect(4)-1,...
                                    cropSelect(1):cropSelect(1)+cropSelect(2)-1);
tic
imgRegistered = imregister(handles.mvRegion,handles.fxRegion,'translation',...
                           handles.optimizer,handles.metric,'DisplayOptimization',true);
rtime=toc;
fprintf('Registered in %3.2f seconds',rtime);
keyImg = [handles.fxRegion,handles.fxRegion];
mvImg = [handles.mvRegion,imgRegistered];
try
    clear(handles.previewImage)
    clear(handles.registerImage)
end
axes(handles.axes1);
handles.registerImage=imshowpair(keyImg,mvImg,'Scaling','joint');
% caxis(handles.axes1,[0,handles.cLimMax]);

handles.previewImage=imshow([handles.fxRegion handles.mvRegion],'parent',handles.axes3);
caxis(handles.axes3,[0,handles.cLimMax]);

guidata(hObject,handles);

% --- Executes on selection change in flatten_method_select.
function flatten_method_select_Callback(hObject, eventdata, handles)
% hObject    handle to flatten_method_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns flatten_method_select contents as cell array
%        contents{get(hObject,'Value')} returns selected item from flatten_method_select
handles=guidata(hObject);
if get(hObject,'Value') == 2
    handles.flattenMethod='Mean';
    disp('method selected: average of planes');
else
    handles.flattenMethod='MaxProject';
    disp('method selected: max projection');
end
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function flatten_method_select_CreateFcn(hObject, eventdata, handles)
% hObject    handle to flatten_method_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in RegisterButton.
function RegisterButton_Callback(hObject, eventdata, handles)
% hObject    handle to RegisterButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close(handles.figure1);

function handles=updateImage_keyRegion_axes(handlesStruct)
%plots a new 2D projection onto keyRegion selection axes
try
    delete(handlesStruct.imgHandle);
    delete(handlesStruct.redboxLine);
end

cla(handlesStruct.axes2);
hold(handlesStruct.axes2,'on');
handlesStruct.imgHandle=imshow(handlesStruct.image,'parent',handlesStruct.axes2);
handlesStruct.yellowBoxLine=plotSquare(handlesStruct.axes2,handlesStruct.yellowBox,[1 1 0]);
hold(handlesStruct.axes2,'off');
caxis(handlesStruct.axes2,[0,handlesStruct.cLimMax]);
axis(handlesStruct.axes2,'equal');
axis(handlesStruct.axes2,'tight');
handles=handlesStruct;

function project2D = load2DProjection(handlesStruct,stackNumber)
%extracts and loads the 2D projection from .stack file
disp('loading stack....');

memMap = memmapfile(handlesStruct.stackFiles(stackNumber).name,'Format','uint16');
filedata = memMap.Data;

% expDimensions = [size(handlesStruct.image,1),size(handlesStruct.image,2), numel(filedata)/prod(size(handlesStruct.image)) ];
expDimensions = [handlesStruct.stDim(2),handlesStruct.stDim(1), numel(filedata)/prod(handlesStruct.stDim(1:2)) ];
stack = reshape(filedata,expDimensions);

if strcmp(handlesStruct.flattenMethod,'MaxProject')
    project2D = max(stack,[],3)';
elseif strcmp(handlesStruct.flattenMethod,'Mean')
    planesIdx = str2num(get(handlesStruct.planes2average,'String'));
    project2D = mean(stack(:,:,planesIdx),3)';
%     project2D = fliplr(project2D); %WRONG, flips l-r
end

disp(sprintf('loaded %s',handlesStruct.stackFiles(stackNumber).name));

    


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
% cropSelection(cropSelection<1) = 1;
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


% --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)
handles=guidata(hObject);
boxWidth = handles.yellowBox(2);
boxHeight = handles.yellowBox(4);
boxCenterX = handles.yellowBox(1) + boxWidth/2;
boxCenterY = handles.yellowBox(3) + boxHeight/2;
pixels2move = 20;
scalefactor = 5;
incr = 1+scalefactor/100;
decr = 1-scalefactor/100;

switch eventdata.Character
    case '+'
        handles.yellowBox = [boxCenterX-boxWidth*incr/2 boxWidth*incr ...
                          boxCenterY-boxHeight*incr/2 boxHeight*incr];       
    case '-'
        handles.yellowBox = [boxCenterX-boxWidth*decr/2 boxWidth*decr ...
                          boxCenterY-boxHeight*decr/2 boxHeight*decr];
    case 'W'
        handles.yellowBox(1:2) = [boxCenterX-boxWidth*incr/2 boxWidth*incr];
        
    case 'w'
        handles.yellowBox(1:2) = [boxCenterX-boxWidth*decr/2 boxWidth*decr];
       
    case 'H'
        handles.yellowBox(3:4) = [boxCenterY-boxHeight*incr/2 boxHeight*incr];  
        
    case 'h'
        handles.yellowBox(3:4) = [boxCenterY-boxHeight*decr/2 boxHeight*decr];
%         
%     case 'C'
%         imgCx = size(handles.image,2)/2;
%         imgCy = size(handles.image,1)/2;
%         handles.yellowBox = [imgCx-boxWidth/2 boxWidth ...
%                           imgCy-boxHeight/2 boxHeight];
end

switch eventdata.Key
    case 'uparrow'
        handles.yellowBox(3) = handles.yellowBox(3)-pixels2move;
    case 'downarrow'
        handles.yellowBox(3) = handles.yellowBox(3)+pixels2move;
    case 'leftarrow'
        handles.yellowBox(1) = handles.yellowBox(1)-pixels2move;
    case 'rightarrow'
        handles.yellowBox(1) = handles.yellowBox(1)+pixels2move;
end

try
    delete(handles.yellowBoxLine);
end

handles.yellowBox = checkDimensions(handles.yellowBox,size(handles.image,2),size(handles.image,1));
handles.yellowBoxLine = plotSquare(handles.axes2,handles.yellowBox,[1,1,0]);
guidata(hObject,handles);



function currStack_Callback(hObject, eventdata, handles)
% hObject    handle to currStack (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of currStack as text
%        str2double(get(hObject,'String')) returns contents of currStack as a double
handles=guidata(hObject);
stackNum = str2num(get(hObject,'String'));
axes(handles.axes2);
handles.image=load2DProjection(handles,stackNum);
handles=updateImage_keyRegion_axes(handles);
cropSelect = round(handles.yellowBox);
handles.fxRegion = handles.keyFrame(cropSelect(3):cropSelect(3)+cropSelect(4)-1,...
                                    cropSelect(1):cropSelect(1)+cropSelect(2)-1);
handles.mvRegion = handles.image(cropSelect(3):cropSelect(3)+cropSelect(4)-1,...
                                    cropSelect(1):cropSelect(1)+cropSelect(2)-1);
handles.previewImage = imshow([handles.fxRegion handles.mvRegion],'parent',handles.axes3);
caxis(handles.axes3,[0,handles.cLimMax]);
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function currStack_CreateFcn(hObject, eventdata, handles)
% hObject    handle to currStack (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function planes2average_Callback(hObject, eventdata, handles)
% hObject    handle to planes2average (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of planes2average as text
%        str2double(get(hObject,'String')) returns contents of planes2average as a double


% --- Executes during object creation, after setting all properties.
function planes2average_CreateFcn(hObject, eventdata, handles)
% hObject    handle to planes2average (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in offsetCheckbox.
function offsetCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to offsetCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of offsetCheckbox


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
