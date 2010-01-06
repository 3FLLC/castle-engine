{
  Copyright 2008-2009 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ TKamVRMLBrowser component, simple VRML browser in a Lazarus component. }
unit KambiVRMLBrowser;

interface

uses Classes, KambiGLControl, VectorMath, Controls,
  VRMLNodes, VRMLGLScene, VRMLScene, Navigation, VRMLGLHeadlight, Areas,
  ShadowVolumes, SceneManagerUnit;

type
  { A simple VRML browser as a Lazarus component. This manages TVRMLGLScene,
    navigator (automatically adjusted to NavigationInfo.type).
    Octress are also automatically used (you only have to set Scene.Spatial
    to anything <> [], like typical [ssRendering, ssDynamicCollisions]).
    You simply call @link(Load) method and all is done.

    This class tries to be a thin (not really "opaque")
    wrapper around Scene / Navigator objects. Which means that
    you can access many functionality by directly accessing
    Scene or Navigator objects methods/properties.
    In particular you're permitted to access and call:

    @unorderedList(
      @item(@link(TVRMLScene.ProcessEvents Scene.ProcessEvents))
      @item(@link(TVRMLScene.Spatial Scene.Spatial),
        and other octree properties)
      @item(@link(TVRMLScene.RegisterCompiledScript Scene.RegisterCompiledScript))
      @item(@link(TVRMLScene.LogChanges Scene.LogChanges))
      @item(Changing VRML graph:

        You can freely change @link(TVRMLScene.RootNode Scene.RootNode)
        contents, provided that you call appropriate Scene.ChangedXxx method.

        You can also freely call events on the VRML nodes.

        You can access BackgroundStack and other stacks.)

      @item(Automatically managed Scene properties, like
        @link(TVRMLScene.BoundingBox Scene.BoundingBox),
        @link(TVRMLScene.TrianglesList Scene.TrianglesList),
        @link(TVRMLScene.ManifoldEdges Scene.ManifoldEdges),
        @link(TVRMLScene.ManifoldEdges Scene.BorderEdges)
        are also free to use.)

      @item(You can change @link(TVRMLGLScene.Optimization
        Scene.Optimization). You can also change rendering attributes
        by @link(TVRMLGLScene.Attributes Scene.Attributes).)
    )

    Some important things that you @italic(cannot) mess with:

    @unorderedList(
      @item(Don't create/free Scene, Navigator and such objects yourself.
        This class manages them, they are always non-nil.)
    )

    This is very simple to use, but note that for more advanced uses
    you're not really expected to extend this class. Instead, you can
    implement something more suitable for you using your own
    TVRMLGLScene and navigator management.
    In other words, remember that this class just provides
    a simple "glue" between the key components of our engine.
    For specialized cases, more complex scenarios may be needed.

    If you're looking for GLWindow descendants that does basically the same
    (easy VRML browser), you want to check out TGLWindowVRMLBrowser
    (file @code(../glwindow/glwindowvrmlbrowser.pas)). }
  TKamVRMLBrowser = class(TKamOpenGLControl)
  private
    FOnNavigatorChanged: TNotifyEvent;
    FScene: TVRMLGLScene;

    FIgnoreAreas: TDynAreaArray;

    function MoveAllowed(ANavigator: TWalkNavigator;
      const ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
      const BecauseOfGravity: boolean): boolean;
    procedure GetCameraHeight(ANavigator: TWalkNavigator;
      out IsAboveTheGround: boolean; out SqrHeightAboveTheGround: Single);

    procedure ScenePostRedisplay(Scene: TVRMLScene);
    procedure VisibleChange(ANavigator: TObject);
    procedure BoundViewpointChanged(Scene: TVRMLScene);
    procedure BoundViewpointVectorsChanged(Scene: TVRMLScene);
    procedure GeometryChanged(Scene: TVRMLScene;
      const SomeLocalGeometryChanged: boolean);

    procedure UpdateCursor(Sender: TObject);
  private
    FShadowVolumesPossible: boolean;
    procedure SetShadowVolumesPossible(const Value: boolean);
  private
    FShadowVolumes: boolean;
    FShadowVolumesDraw: boolean;
    SV: TShadowVolumes;

    SceneManager: TSceneManager;
    { Set all SceneManager properties. This is a temporary solution,
      in the future initializing SceneManager properties should be integrated
      with this unit, and generally most of this unit's functionality
      should move to scene manager. }
    procedure InitSceneManager;
  protected
    procedure DoBeforeDraw; override;
    procedure DoDraw; override;
    procedure DoGLContextInit; override;
    procedure DoGLContextClose; override;
    procedure MouseDownEvent(Button: Controls.TMouseButton;
      Shift:TShiftState; X,Y:Integer); override;
    procedure MouseUpEvent(Button: Controls.TMouseButton;
      Shift:TShiftState; X,Y:Integer); override;
    procedure MouseMoveEvent(Shift: TShiftState; NewX, NewY: Integer); override;
    procedure KeyDownEvent(var Key: Word; Shift: TShiftState); override;
    procedure KeyUpEvent(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner :TComponent); override;
    destructor Destroy; override;

    { Creates new @link(Scene), with new navigator and such. }
    procedure Load(const SceneFileName: string);
    procedure Load(ARootNode: TVRMLNode; const OwnsRootNode: boolean);

    property Scene: TVRMLGLScene read FScene;

    procedure Resize; override;
    procedure Idle; override;

    { Mouse movement and clicks within areas here will be ignored by VRML browser.
      That is, they will be treated like mouse was outside of VRML browser.

      This is useful if you drawn some 2D controls in your OnDraw,
      and you want to handle clicks on them yourself (with OnClick or such).
      Thanks to IgnoreAreas, VRML browser will not intercept those clicks
      (not send them to some VRML TouchSensors etc.), mouse cursor will
      also remain normal within these areas (regardless of whether mouse
      is over some sensor).

      Note that their coords are in screen coordinates, just like MouseX,
      MouseY. This means that 0,0 is the upper-left corner (unlike typical
      OpenGL 2D projection, which has 0,0 in lower-left corner). }
    property IgnoreAreas: TDynAreaArray read FIgnoreAreas;
  published
    property OnNavigatorChanged: TNotifyEvent
      read FOnNavigatorChanged write FOnNavigatorChanged;

    { Should we make shadow volumes possible?

      This can be changed only when the context is not initialized,
      that is only when the window is currently closed.
      Reason: to make shadows possible, we have to initialize gl context
      specially (with stencil buffer).

      Note that the shadows will not be actually rendered until you also
      set ShadowVolumes := true. }
    property ShadowVolumesPossible: boolean
      read FShadowVolumesPossible write SetShadowVolumesPossible default false;

    { Should we render with shadow volumes?
      You can change this at any time, to switch rendering shadows on/off.

      This works only if ShadowVolumesPossible is @true.

      Note that the shadow volumes algorithm makes some requirements
      about the 3D model: it must be 2-manifold, that is have a correctly
      closed volume. Otherwise, rendering results may be bad. You can check
      Scene.BorderEdges.Count before using this: BorderEdges.Count = 0 means
      that model is Ok, correct manifold.

      For shadows to be actually used you still need a light source
      marked as the main shadows light (kambiShadows = kambiShadowsMain = TRUE),
      see [http://vrmlengine.sourceforge.net/kambi_vrml_extensions.php#section_ext_shadows]. }
    property ShadowVolumes: boolean
      read FShadowVolumes write FShadowVolumes default false;

    { Actually draw the shadow volumes to the color buffer, for debugging.
      If shadows are rendered (see ShadowVolumesPossible and ShadowVolumes),
      you can use this to actually see shadow volumes, for debug / demo
      purposes. Shadow volumes will be rendered on top of the scene,
      as yellow blended polygons. }
    property ShadowVolumesDraw: boolean
      read FShadowVolumesDraw write FShadowVolumesDraw default false;
  end;

procedure Register;

implementation

{ The implementation is very very similar to GLWindowVRMLBrowser implementation.
  In fact, some code parts are even identical... A work to move more
  logic to TVRMLScene (which could be used then by both this unit and
  GLWindowVRMLBrowser, without any code duplication) is ongoing. }

{ This uses OctreeCollisions, so either OctreeDynamicCollisions
  or OctreeCollidableTriangles, whichever is available. }

uses Boxes3d, VRMLOpenGLRenderer, GL, GLU,
  KambiClassUtils, KambiUtils, SysUtils, Object3dAsVRML,
  KambiGLUtils, KambiFilesUtils, VRMLTriangle,
  RaysWindow, BackgroundGL, KeysMouse;

procedure Register;
begin
  RegisterComponents('Kambi',[TKamVRMLBrowser]);
end;

{ TKamVRMLBrowser ----------------------------------------------------------- }

constructor TKamVRMLBrowser.Create(AOwner :TComponent);
begin
  inherited;

  SceneManager := TSceneManager.Create;

  FIgnoreAreas := TDynAreaArray.Create;

  Load(nil, true);
end;

destructor TKamVRMLBrowser.Destroy;
begin
  FreeAndNil(SceneManager);
  FreeAndNil(FScene);
  Navigator.Free;
  Navigator := nil;
  FreeAndNil(FIgnoreAreas);
  inherited;
end;

procedure TKamVRMLBrowser.Load(const SceneFileName: string);
begin
  Load(LoadAsVRML(SceneFileName, false), true);
end;

procedure TKamVRMLBrowser.Load(ARootNode: TVRMLNode; const OwnsRootNode: boolean);
begin
  FreeAndNil(FScene);
  Navigator.Free;
  Navigator := nil;

  FScene := TVRMLGLScene.Create(ARootNode, OwnsRootNode, roSeparateShapes);

  { initialize octrees titles }
  Scene.TriangleOctreeProgressTitle := 'Building triangle octree';
  Scene.ShapeOctreeProgressTitle := 'Building Shape octree';

  { init Navigator }
  Navigator := Scene.CreateNavigator(nil);
  Navigator.OnVisibleChange := @VisibleChange;
  Scene.Navigator := Navigator;

  if Navigator is TWalkNavigator then
  begin
    WalkNav.OnMoveAllowed := @MoveAllowed;
    WalkNav.OnGetCameraHeight := @GetCameraHeight;
  end;

  { prepare for events procesing (although we let the decision whether
    to turn ProcessEvent := true to the caller). }
  Scene.ResetWorldTimeAtLoad;
  Scene.OnPostRedisplay := @ScenePostRedisplay;
  Scene.OnBoundViewpointVectorsChanged := @BoundViewpointVectorsChanged;
  Scene.ViewpointStack.OnBoundChanged := @BoundViewpointChanged;
  Scene.OnGeometryChanged := @GeometryChanged;
  Scene.OnPointingDeviceSensorsChange := @UpdateCursor;

  InitSceneManager;

  { Call initial ViewerChanged (this allows ProximitySensors to work
    as soon as ProcessEvent becomes true). }
  Scene.ViewerChanged(Navigator, SceneManager.ViewerToChanges);

  { allow the scene to use it's own lights }
  Scene.Attributes.UseLights := true;
  Scene.Attributes.FirstGLFreeLight := 1;

  if ContextInitialized then
  begin
    Resize;
    Invalidate;
  end;
end;

procedure TKamVRMLBrowser.InitSceneManager;
begin
  SceneManager.Scene := Scene;
  SceneManager.Navigator := Navigator;
  SceneManager.ShadowVolumesPossible := ShadowVolumesPossible;
  SceneManager.ShadowVolumes := ShadowVolumes;
  SceneManager.ShadowVolumesDraw := ShadowVolumesDraw;
  SceneManager.SV := SV;
  SceneManager.ViewportX := 0;
  SceneManager.ViewportY := 0;
  SceneManager.ViewportWidth := Width;
  SceneManager.ViewportHeight := Height;
end;

procedure TKamVRMLBrowser.DoBeforeDraw;
begin
  InitSceneManager;
  SceneManager.PrepareRender;
  inherited;
end;

procedure TKamVRMLBrowser.DoDraw;
begin
  InitSceneManager;
  SceneManager.Render;
  inherited;
end;

procedure TKamVRMLBrowser.DoGLContextInit;
begin
  inherited;
  glEnable(GL_LIGHTING);

  if ShadowVolumesPossible then
  begin
    SV := TShadowVolumes.Create;
    SV.InitGLContext;
  end;
end;

procedure TKamVRMLBrowser.DoGLContextClose;
begin
  { This may be called by inherited destructor, when our own destructor
    already destroyed Scene. (Testcase: open form with this component
    in Lazarus, then close Lazarus). So we secure against it. }
  if Scene <> nil then
    Scene.CloseGL;

  FreeAndNil(SV);

  inherited;
end;

procedure TKamVRMLBrowser.Idle;
begin
  inherited;
  Scene.IncreaseWorldTime(Fps.IdleSpeed);
end;

procedure TKamVRMLBrowser.Resize;
begin
  inherited;
  if not MakeCurrent then Exit;
  Scene.GLProjection(Navigator, Scene.BoundingBox,
    Width, Height, ShadowVolumesPossible);
end;

procedure TKamVRMLBrowser.MouseDownEvent(Button: Controls.TMouseButton;
  Shift:TShiftState; X,Y:Integer);
var
  MyButton: KeysMouse.TMouseButton;
begin
  inherited;

  if LMouseButtonToMyMouseButton(Button, MyButton) then
    Scene.MouseDown(MouseX, MouseY, MyButton, MousePressed);
end;

procedure TKamVRMLBrowser.MouseUpEvent(Button: Controls.TMouseButton;
  Shift:TShiftState; X,Y:Integer);
var
  MyButton: KeysMouse.TMouseButton;
begin
  inherited;

  if LMouseButtonToMyMouseButton(Button, MyButton) then
    Scene.MouseUp(MouseX, MouseY, MyButton, MousePressed);
end;

procedure TKamVRMLBrowser.UpdateCursor(Sender: TObject);

  function SensorsCount: Cardinal;
  begin
    if Scene.PointingDeviceSensors <> nil then
      Result := Scene.PointingDeviceSensors.EnabledCount else
      Result := 0;
    if Scene.PointingDeviceActiveSensor <> nil then
      Inc(Result);
  end;

begin
  { I want to keep assertion that CursorNonMouseLook = crHandPoint when
    we're over or keeping active some pointing-device sensors. }
  if SensorsCount <> 0 then
    CursorNonMouseLook := crHandPoint else
    CursorNonMouseLook := crDefault;
end;

procedure TKamVRMLBrowser.MouseMoveEvent(Shift: TShiftState; NewX, NewY: Integer);
begin
  inherited;
  Scene.MouseMove(MouseX, MouseY, NewX, NewY, MousePressed, Pressed);
end;

procedure TKamVRMLBrowser.KeyDownEvent(var Key: Word; Shift: TShiftState);
var
  MyKey: TKey;
  MyCharKey: char;
begin
  inherited;

  LKeyToMyKey(Key, Shift, MyKey, MyCharKey);

  if (MyKey <> K_None) or (MyCharKey <> #0) then
    Scene.KeyDown(MyKey, MyCharKey, Pressed);
end;

procedure TKamVRMLBrowser.KeyUpEvent(var Key: Word; Shift: TShiftState);
var
  MyKey: TKey;
  MyCharKey: char;
begin
  inherited;

  LKeyToMyKey(Key, Shift, MyKey, MyCharKey);

  if (MyKey <> K_None) or (MyCharKey <> #0) then
    Scene.KeyUp(Key, MyCharKey, Pressed);
end;

function TKamVRMLBrowser.MoveAllowed(ANavigator: TWalkNavigator;
  const ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
  const BecauseOfGravity: boolean): boolean;
begin
  if Scene.OctreeCollisions <> nil then
  begin
    Result := Scene.OctreeCollisions.MoveAllowed(
      ANavigator.CameraPos, ProposedNewPos, NewPos, ANavigator.CameraRadius);
  end else
  begin
    Result := true;
    NewPos := ProposedNewPos;
  end;

  { Don't let user to fall outside of the box because of gravity. }
  if Result and BecauseOfGravity then
    Result := SimpleKeepAboveMinPlane(NewPos, Scene.BoundingBox,
      ANavigator.GravityUp);
end;

procedure TKamVRMLBrowser.GetCameraHeight(ANavigator: TWalkNavigator;
  out IsAboveTheGround: boolean; out SqrHeightAboveTheGround: Single);
var
  GroundItem: PVRMLTriangle;
begin
  if Scene.OctreeCollisions <> nil then
  begin
    Scene.OctreeCollisions.GetCameraHeight(
      ANavigator.CameraPos,
      ANavigator.GravityUp,
      IsAboveTheGround, SqrHeightAboveTheGround, GroundItem,
      nil, nil);
  end else
  begin
    { When octree is not available, we actually don't want gravity to
      cause falling down. So return values pretending we're standing
      still on the ground. }
    IsAboveTheGround := true;
    SqrHeightAboveTheGround := Sqr(ANavigator.CameraPreferredHeight);
  end;
end;

procedure TKamVRMLBrowser.ScenePostRedisplay(Scene: TVRMLScene);
begin
  Invalidate;
end;

procedure TKamVRMLBrowser.VisibleChange(ANavigator: TObject);
begin
  { Navigator.OnVisibleChange callback is initialized in constructor
    before Scene is initialized. So to be on the safest side, we check
    here Scene <> nil. }

  if Scene <> nil then
  begin
    InitSceneManager;
    Scene.ViewerChanged(Navigator, SceneManager.ViewerToChanges);
  end;

  if Assigned(OnNavigatorChanged) then
    OnNavigatorChanged(ANavigator);
end;

procedure TKamVRMLBrowser.BoundViewpointChanged(Scene: TVRMLScene);
begin
  Scene.NavigatorBindToViewpoint(Navigator, false);
end;

procedure TKamVRMLBrowser.BoundViewpointVectorsChanged(Scene: TVRMLScene);
begin
  Scene.NavigatorBindToViewpoint(Navigator, true);
end;

procedure TKamVRMLBrowser.GeometryChanged(Scene: TVRMLScene;
  const SomeLocalGeometryChanged: boolean);
begin
  { Scene.GeometryChanged possibly cleared pointing device info by
    PointingDeviceClear. This means that cursor must be updated.
    TODO: call this automatically by Scene? }
  UpdateCursor(Scene);
end;

procedure TKamVRMLBrowser.SetShadowVolumesPossible(const Value: boolean);
begin
  if ContextInitialized then
    raise Exception.Create('You can''t change ShadowVolumesPossible ' +
      'while the context is already initialized');
  FShadowVolumesPossible := Value;

  { TODO: hmm, there's no way to request stencil buffer from TOpenGLControl?
    Looking in the sources, for GTK always at least 1-bit stencil buffer is
    requested (pretty stupid and worthless?), for Windows nothing is requested.
    There's no way to workaround it, this must be fixed in OpenGLContext
    for TKamVRMLBrowser to work reliably. }

{  if ShadowVolumesPossible then
    StencilBufferBits := 8 else
    StencilBufferBits := 0;}
end;

end.
