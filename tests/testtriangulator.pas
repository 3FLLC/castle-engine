{
  Copyright 2011-2012 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ }
unit TestTriangulator;

{ Besides doing some tests, we can also make a visualization of triangulation.
  This results in a series of images showing how triangulation progresses,
  hopefully useful to debug TriangulateFace problems.

  Simply define the symbol below, and run the tests to get the images.
  Console will contain messages about where the images are written,
  and how the triangulation progresses.
  For better debugging, you may also want to:
  - Change beginning test_castle_game_engine.lpr to run only TestTriangulateFace
  - Change TestTriangulateFace implementation to run only one DoPolygon,
    the one that interests you.
}
{ $define VISUALIZE_TRIANGULATION}

{ TODO:
  - Why with and without VISUALIZE_TRIANGULATION we observe totally
    different reports ?!?!?!?!?!?!?!?!
    With VISUALIZE_TRIANGULATION I see now only 1 face,
    and much more "Empty tri is" messages?

    Just recompiling causes different behavior.
    Actually, just running the test multiple times can change behavior.
    For Polygon_3_5, I can sometimes can 4, sometimes 3, sometimes 0 calls
    to Face callback.
    Why?
    Do we read/write over some garbage memory maybe?
    And this is with VISUALIZE_TRIANGULATION undefined, so cannot blame FpCanvas.

  - Finish visualization:
    add showing which triangles are cut off on images.
    draw indexes of tri corners.
}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry, VectorMath, Triangulator,
  FpImage, FpCanvas, FpImgCanv, FpWritePNG;

type
  TTestTriangulator = class(TTestCase)
  private
    { private vars for Face callback }
    Vertexes: PVector3Single;
    CountVertexes: Integer;
    TriangleCount: Cardinal;
    {$ifdef VISUALIZE_TRIANGULATION}
    ImageFileNameFormat: string;
    Image: TFPCustomImage;
    Canvas: TFPCustomCanvas;
    VisualizeX, VisualizeY: Cardinal;
    MinV, MaxV: TVector3Single;
    function VisualizePoint(const P: TVector3Single): TPoint;
    {$endif VISUALIZE_TRIANGULATION}
    procedure Face(const Tri: TVector3Longint);
  published
    procedure TestIndexedConcavePolygonNormal;
    procedure TestTriangulateFace;
  end;

implementation

uses CastleStringUtils, CastleUtils;

procedure TTestTriangulator.TestIndexedConcavePolygonNormal;
const
  Verts: array [0..3] of TVector3Single =
  ( (-1, 0, 0),
    (0, 1, 0),
    (1, -1, 0),
    (0, 0, 0)
  );
  Indexes: array [0..3] of LongInt = (0, 1, 2, 3);
begin
  Assert(VectorsEqual(
    IndexedPolygonNormal(@Indexes, High(Indexes) + 1,
      @Verts, High(Verts) + 1, ZeroVector3Single, false),
    Vector3Single(0, 0, -1)));

  { This is an example polygon that cannot be handled
    by IndexedConvexPolygonNormal }
  Assert(not VectorsEqual(
    IndexedConvexPolygonNormal(@Indexes, High(Indexes) + 1,
      @Verts, High(Verts) + 1, ZeroVector3Single),
    Vector3Single(0, 0, -1)));
  Assert(not VectorsEqual(
    IndexedPolygonNormal(@Indexes, High(Indexes) + 1,
      @Verts, High(Verts) + 1, ZeroVector3Single, true),
    Vector3Single(0, 0, -1)));
end;

procedure TTestTriangulator.Face(const Tri: TVector3Longint);
{$ifdef VISUALIZE_TRIANGULATION}
var
  FileName: string;
  Writer: TFPWriterPNG;
{$endif VISUALIZE_TRIANGULATION}
begin
  Inc(TriangleCount);
  Writeln('Triangle ', TriangleCount);

  {$ifdef VISUALIZE_TRIANGULATION}
  FileName := Format(ImageFileNameFormat, [TriangleCount]);

  { recreate Writer each time, to workaround http://bugs.freepascal.org/view.php?id=21840 }
  Writer := TFPWriterPNG.Create;
  try
    Writer.Indexed := false;
    Image.SaveToFile(FileName, Writer);
  finally FreeAndNil(Writer) end;

  Writeln('Triangle ', TriangleCount, ': ', Tri[0], ' ', Tri[1], ' ', Tri[2], ' (saved to ', FileName, ')');
  {$endif VISUALIZE_TRIANGULATION}
end;

{$ifdef VISUALIZE_TRIANGULATION}
function TTestTriangulator.VisualizePoint(const P: TVector3Single): TPoint;
begin
  Result := Point(
    Round(MapRange(P[VisualizeX], MinV[VisualizeX], MaxV[VisualizeX], 0, Image.Width)),
    Round(MapRange(P[VisualizeY], MinV[VisualizeY], MaxV[VisualizeY], 0, Image.Height))
  );
end;
{$endif VISUALIZE_TRIANGULATION}

procedure TTestTriangulator.TestTriangulateFace;

  procedure DoPolygon(const AVertexes: array of TVector3Single;
    const Name: string;
    AVisualizeX, AVisualizeY: Cardinal);
  {$ifdef VISUALIZE_TRIANGULATION}
  var
    I: Integer;
  {$endif VISUALIZE_TRIANGULATION}
  begin
    try
      Vertexes := @AVertexes;
      CountVertexes := High(AVertexes) + 1;
      TriangleCount := 0;

      {$ifdef VISUALIZE_TRIANGULATION}
      Image := TFPMemoryImage.Create(1024, 1024);
      Image.UsePalette := false;
      { TFPImageCanvas has some abstract methods not overridden.
        This is FPC bug in FpImgCanv. Ignore following warnings. }
      {$warnings off}
      Canvas := TFPImageCanvas.Create(Image);
      {$warnings on}

      ImageFileNameFormat :=
        SUnformattable(InclPathDelim(GetTempDir) + Name) + '_%d.png';
      VisualizeX := AVisualizeX;
      VisualizeY := AVisualizeY;

      MinV := Vertexes[0];
      MaxV := Vertexes[0];
      for I := 1 to CountVertexes - 1 do
      begin
        MinTo1st(MinV[0], Vertexes[I][0]);
        MinTo1st(MinV[1], Vertexes[I][1]);
        MinTo1st(MinV[2], Vertexes[I][2]);
        MaxTo1st(MaxV[0], Vertexes[I][0]);
        MaxTo1st(MaxV[1], Vertexes[I][1]);
        MaxTo1st(MaxV[2], Vertexes[I][2]);
      end;

      Canvas.Pen.FPColor := FPColor($FFFF, $FFFF, $FFFF);
      Canvas.MoveTo(VisualizePoint(Vertexes[0]));
      for I := 1 to CountVertexes - 1 do
        Canvas.LineTo(VisualizePoint(Vertexes[I]));
      Canvas.LineTo(VisualizePoint(Vertexes[0]));
      {$endif VISUALIZE_TRIANGULATION}

      TriangulateFace(nil, CountVertexes, @Vertexes, @Face, 0);
    finally
      {$ifdef VISUALIZE_TRIANGULATION}
      FreeAndNil(Image);
      FreeAndNil(Canvas);
      {$endif VISUALIZE_TRIANGULATION}
    end;
  end;

const
  { From polygon_3_5.wrl corrected by JA by removing dup vertexes
    in TriangulateFace. }
  Polygon_3_5: array [0..6] of TVector3Single = (
    (0.216, 0, 0.413),
    (0.528, 0, 0.000),
    (1.000, 0, 0.913),
    (0.528, 0, 0.413),
    (0.316, 0, 1.000),
    (0.000, 0, 0.630),
    (0.528, 0, 0.413)
  );
begin
  DoPolygon(Polygon_3_5, 'polygon_3_5', 0, 2);
  { TODO: test that results are same as hardcoded results }
  { TODO: maybe test that resulting edges do not cross each other
    or original polygon edges? But it's not so easy, as on non-trivial
    polygons we will have colinear edges. }
end;

initialization
  RegisterTest(TTestTriangulator);
end.
