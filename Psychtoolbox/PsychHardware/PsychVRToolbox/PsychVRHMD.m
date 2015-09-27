function varargout = PsychVRHMD(cmd, varargin)
% PsychVRHMD() - High level driver for VR HMD devices.
%
% This driver bundles all the common high level functionality
% of different Virtual Reality Head mounted displays into one
% function.
%
% It dispatches generic calls into appropriate device specific
% drivers as needed.
%
% Usage:
%
% oldverbosity = PsychVRHMD('Verbosity' [, newverbosity]);
% - Get/Set level of verbosity for driver status messages, warning messages,
% error messages etc. 'newverbosity' is the optional new verbosity level,
% 'oldverbosity' is the currently set verbosity level - ie. before changing
% it.  Valid settings are: 0 = Silent, 1 = Errors only, 2 = Warnings, 3 = Info,
% 4 = Debug.
%
%
% hmd = PsychVRHMD('AutoSetupHMD' [, basicTask][, basicRequirements][, basicQuality][, vendor][, deviceIndex]);
% - Automatically detect the first connected HMD, set it up with reasonable
% default parameters, and return a device handle 'hmd' to it. If the system
% does not support any HMDs, not even emulated ones, just does nothing and
% returns an empty handle, ie., hmd = [], so caller can cope with that.
%
% Optional parameters: 'basicTask' what kind of task should be implemented.
% The default is 'Tracked3DVR', which means to setup for stereoscopic 3D
% rendering, driven by head motion tracking, for a fully immersive experience
% in some kind of 3D virtual world. This is the default if omitted. The task
% 'Stereoscopic' sets up for display of stereoscopic stimuli, but without
% head tracking. 'Monoscopic' sets up for display of monocular stimuli, ie.
% the HMD is just used as a special kind of standard display monitor.
%
% 'basicRequirements' defines basic requirements for the task. Currently
% defined are the following strings which can be combined into a single
% 'basicRequirements' string: 'LowPersistence' = Try to keep exposure
% time of visual images on the retina low if possible, ie., try to approximate
% a pulse-type display instead of a hold-type display if possible.
% 'FastResponse' = Try to switch images with minimal delay and fast
% pixel switching time, e.g., by use of panel overdrive processing.
% 'TimingSupport' = Support some hardware specific means of timestamping
% or latency measurements.
%
% These basic requirements get translated into a device specific set of
% settings. The settings can also be specific to the selected 'basicTask',
% and if a quality vs. performance / system load tradeoff is unavoidable
% then the 'basicQuality' parameter may modulate the strategy.
%
% 'basicQuality' defines the basic tradeoff between quality and required
% computational power. A setting of 0 gives lowest quality, but with the
% lowest performance requirements. A setting of 1 gives maximum quality at
% maximum computational load. Values between 0 and 1 change the quality to
% performance tradeoff.
%
% By default all currently supported types of HMDs from different
% vendors are probed and the first one found is used. If the optional
% parameter 'vendor' is provided, only devices from that vendor are
% detected and the first detected device is chosen.
%
% If additionally the optional 'deviceIndex' parameter is provided then
% that specific device 'deviceIndex' from that 'vendor' is opened and set up.
%
%
% PsychVRHMD('SetAutoClose', hmd, mode);
% - Set autoclose mode for HMD with handle 'hmd'. 'mode' can be
% 0 (this is the default) to not do anything special. 1 will close
% the HMD 'hmd' when the onscreen window is closed which displays
% on the HMD. 2 will do the same as 1, but close all open HMDs and
% shutdown the complete driver and runtime - a full cleanup.
%
%
% isOpen = PsychVRHMD('IsOpen', hmd);
% - Returns 1 if 'hmd' corresponds to an open HMD, 0 otherwise.
%
%
% PsychVRHMD('Close' [, hmd])
% - Close provided HMD device 'hmd'. If no 'hmd' handle is provided,
% all HMDs will be closed and the driver will be shutdown.
%
%
% info = PsychVRHMD('GetInfo', hmd);
% - Retrieve a struct 'info' with information about the HMD 'hmd'.
% The returned info struct contains at least the following standardized
% fields with information:
% handle = Driver internal handle for the specific HMD.
% driver = Function handle to the actual driver for the HMD, e.g., @PsychOculusVR.
% type   = Defines the type/vendor of the device, e.g., 'Oculus'.
% modelName = Name string with the name of the model of the device, e.g., 'Rift DK2'.
% 
% The info struct may contain much more vendor specific information, but the above
% set is supported across all devices.
%
%
% PsychVRHMD('SetupRenderingParameters', hmd [, basicTask='Tracked3DVR'][, basicRequirements][, basicQuality=0][, fov=[HMDRecommended]][, pixelsPerDisplay=1])
% - Query the HMD 'hmd' for its properties and setup internal rendering
% parameters in preparation for opening an onscreen window with PsychImaging
% to display properly on the HMD. See section about 'AutoSetupHMD' above for
% the meaning of the optional parameters 'basicTask', 'basicRequirements'
% and 'basicQuality'.
%
% 'fov' Optional field of view in degrees, from line of sight: [leftdeg, rightdeg,
% updeg, downdeg]. If 'fov' is omitted, the HMD runtime will be asked for a
% good default field of view and that will be used. The field of view may be
% dependent on the settings in the HMD user profile of the currently selected
% user.
%
% 'pixelsPerDisplay' Ratio of the number of render target pixels to display pixels
% at the center of distortion. Defaults to 1.0 if omitted. Lower values can
% improve performance, at lower quality.
%
%
% PsychVRHMD('SetBasicQuality', hmd, basicQuality);
% - Set basic level of quality vs. required GPU performance.
%
%
% PsychVRHMD('SetHSWDisplayDismiss', hmd [, dismissTypes=1+2+4]);
% - Set how the user can dismiss the "Health and safety warning display".
% 'dismissTypes' can be -1 to disable the HSWD, or a value >= 0 to show
% the HSWD until a timeout and or until the user dismisses the HSWD.
% The following flags can be added to define type of dismissal:
%
% +0 = Display until timeout, if any. Will wait forever if there isn't any timeout!
% +1 = Dismiss via keyboard keypress.
% +2 = Dismiss via mouse click or mousepad tap.
% +4 = Dismiss via a tap to the HMD (detected via accelerometer).
%
%
% [bufferSize, imagingFlags, stereoMode] = PsychVRHMD('GetClientRenderingParameters', hmd);
% - Retrieve recommended size in pixels 'bufferSize' = [width, height] of the client
% renderbuffer for each eye for rendering to the HMD. Returns parameters
% previously computed by PsychVRHMD('SetupRenderingParameters', hmd).
%
% Also returns 'imagingFlags', the required imaging mode flags for setup of
% the Screen imaging pipeline. Also returns the needed 'stereoMode' for the
% pipeline.
%
% This function is usually called by PsychImaging(), you don't need to deal
% with it.
%
%
% isOutput = PsychVRHMD('IsHMDOutput', hmd, scanout);
% - Returns 1 (true) if 'scanout' describes the video output to which the
% HMD 'hmd' is connected. 'scanout' is a struct returned by the Screen
% function Screen('ConfigureDisplay', 'Scanout', screenid, outputid);
% This allows probing video outputs to find the one which feeds the HMD.
%
%
% headToEyeShiftv = PsychVRHMD('GetEyeShiftVector', hmd, eye);
% - Retrieve 3D translation vector [tx, ty, tz] that defines the 3D position of the given
% eye 'eye' for the given HMD 'hmd', relative to the origin of the local head/HMD
% reference frame. This is needed to translate a global head pose into a eye
% pose, e.g., to translate the output of PsychVRHMD('GetEyePose') into actual
% tracked/predicted eye locations for stereo rendering.
%
%
% [projL, projR] = PsychVRHMD('GetStaticRenderParameters', hmd [, clipNear=0.01][, clipFar=10000.0]);
% - Retrieve parameters needed to setup the intrinsic parameters of the virtual
% camera for scene rendering.
%
% 'clipNear' Optional near clipping plane for OpenGL. Defaults to 0.01.
% 'clipFar' Optional far clipping plane for OpenGL. Defaults to 10000.0.
%
% Return arguments:
%
% 'projL' is the 4x4 OpenGL projection matrix for the left eye rendering.
% 'projR' is the 4x4 OpenGL projection matrix for the right eye rendering.
% Please note that projL and projR are usually identical for typical rendering
% scenarios.
%
%
% PsychVRHMD('Start', hmd);
% - Start live operations of the 'hmd', e.g., head tracking.
%
%
% PsychVRHMD('Stop', hmd);
% - Stop live operations of the 'hmd', e.g., head tracking.
%
%

% History:
% 23-Sep-2015  mk  Written.

% Global GL handle for access to OpenGL constants needed in setup:
global GL;

if nargin < 1 || isempty(cmd)
  help PsychVRHMD;
  return;
end

% Autodetect first connected HMD and open a connection to it. Open a
% emulated one, if none can be detected. Perform basic setup with
% default configuration, create a proper PsychImaging task.
if strcmpi(cmd, 'AutoSetupHMD')
  if length(varargin) >= 1 && ~isempty(varargin{1})
    basicTask = varargin{1};
  else
    basicTask = 'Tracked3DVR';
  end

  if length(varargin) >= 2 && ~isempty(varargin{2})
    basicRequirements = varargin{2};
  else
    basicRequirements = '';
  end

  if length(varargin) >= 3 && ~isempty(varargin{3})
    basicQuality = varargin{3};
  else
    basicQuality = 0;
  end

  if length(varargin) >= 5 && ~isempty(varargin{5})
    deviceIndex = varargin{5};
  else
    deviceIndex = [];
  end

  if length(varargin) >= 4 && ~isempty(varargin{4})
    vendor = varargin{4};
    if strcmpi(vendor, 'Oculus')
      hmd = PsychOculusVR('AutoSetupHMD', basicTask, basicRequirements, basicQuality, deviceIndex);

      % Return the handle:
      varargout{1} = hmd;
      return;
    end

    error('AutoSetupHMD: Invalid ''vendor'' requested. This vendor is not supported.');
  end

  % Probe sequence:
  hmd = [];

  % Oculus runtime supported and online? At least one real HMD connected?
  if PsychOculusVR('Supported') && PsychOculusVR('GetCount') > 0
    % Yes. Use that one. This will also inject a proper PsychImaging task
    % for setup of the imaging pipeline:
    hmd = PsychOculusVR('AutoSetupHMD', basicTask, basicRequirements, basicQuality, deviceIndex);

    % Return the handle:
    varargout{1} = hmd;
    return;
  end

  % Add probe and autosetup calls for other HMD vendors here...

  % No success with finding any real supported HMD so far. Try to find a driver
  % that at least supports an emulated HMD for very basic testing:
  if PsychOculusVR('Supported')
    hmd = PsychOculusVR('AutoSetupHMD', basicTask, basicRequirements, basicQuality, deviceIndex);
    varargout{1} = hmd;
    return;
  end

  % Add probe for other emulated HMD drivers here ...

  % If we reach this point then it is game over:
  fprintf('PsychVRHMD:AutoSetupHMD: Could not autosetup any HMDs, real or emulated, for any HMD vendor. Game over!\n');

  % Return an empty handle to signal lack of VR HMD support to caller,
  % so caller can cope with it somehow:
  varargout{1} = [];
  return;
end

% If the cmd could not get dispatched by us, funnel it to the
% vendor specific driver:
% 'cmd' so far not dispatched? Let's assume it is a command
% meant for the HMD specific driver:
if (length(varargin) >= 1) && isstruct(varargin{1})
  myhmd = varargin{1};
  [ varargout{1:nargout} ] = myhmd.driver(cmd, myhmd, varargin{2:end});
end

end
