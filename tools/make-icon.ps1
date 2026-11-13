param([string]$OutIco, [string]$PreviewPng)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Drawing2D; using System.IO; using System.Collections.Generic;
public static class IconMaker {
  static PointF P(float cx, float cy, float r, float deg) { double a = deg * Math.PI / 180; return new PointF(cx + (float)(Math.Cos(a) * r), cy + (float)(Math.Sin(a) * r)); }
  static GraphicsPath Rounded(float x, float y, float w, float h, float r) {
    var p = new GraphicsPath(); float d = r * 2;
    p.AddArc(x, y, d, d, 180, 90); p.AddArc(x + w - d, y, d, d, 270, 90);
    p.AddArc(x + w - d, y + h - d, d, d, 0, 90); p.AddArc(x, y + h - d, d, d, 90, 90); p.CloseFigure(); return p;
  }
  // Tapered ray from radius r0 to r1 along angle deg, widths w0 -> w1, rounded ends.
  static void Spoke(Graphics g, Brush b, float cx, float cy, float r0, float r1, float w0, float w1, float deg) {
    var a = P(cx, cy, r0, deg); var c = P(cx, cy, r1, deg);
    using (var path = new GraphicsPath()) {
      path.AddPolygon(new[] { P(a.X, a.Y, w0 / 2, deg - 90), P(c.X, c.Y, w1 / 2, deg - 90), P(c.X, c.Y, w1 / 2, deg + 90), P(a.X, a.Y, w0 / 2, deg + 90) });
      g.FillPath(b, path);
    }
    g.FillEllipse(b, a.X - w0 / 2, a.Y - w0 / 2, w0, w0);
    g.FillEllipse(b, c.X - w1 / 2, c.Y - w1 / 2, w1, w1);
  }
  public static Bitmap Draw(int s) {
    var bmp = new Bitmap(s, s); var g = Graphics.FromImage(bmp);
    g.SmoothingMode = SmoothingMode.AntiAlias; g.PixelOffsetMode = PixelOffsetMode.HighQuality; g.Clear(Color.Transparent);
    float k = s / 256f; bool tiny = s <= 24;
    // Tile
    using (var tile = Rounded(0, 0, s, s, s * 0.2f))
    using (var bg = new LinearGradientBrush(new PointF(0, 0), new PointF(0, s), Color.FromArgb(46, 44, 56), Color.FromArgb(22, 21, 28)))
      g.FillPath(bg, tile);
    float cx = s / 2f, cy = s * (tiny ? 0.56f : 0.58f), r = s * (tiny ? 0.36f : 0.34f);
    float thick = s * (tiny ? 0.16f : 0.12f);
    // Arc segments: green -> yellow -> orange -> red (135..405 deg)
    Color[] cols = { Color.FromArgb(52, 211, 120), Color.FromArgb(250, 204, 21), Color.FromArgb(251, 140, 40), Color.FromArgb(239, 58, 58) };
    float start = 135, sweep = 270, seg = sweep / cols.Length, gap = tiny ? 0 : 4;
    for (int i = 0; i < cols.Length; i++) {
      using (var pen = new Pen(cols[i], thick)) {
        pen.StartCap = (i == 0) ? LineCap.Round : LineCap.Flat; pen.EndCap = (i == cols.Length - 1) ? LineCap.Round : LineCap.Flat;
        g.DrawArc(pen, cx - r, cy - r, 2 * r, 2 * r, start + i * seg + (i > 0 ? gap / 2 : 0), seg - (i > 0 && i < cols.Length - 1 ? gap : gap / 2));
      }
    }
    // Starburst of terracotta rays in the middle; one red ray is the needle.
    float needleDeg = start + sweep * 0.9f;
    var terra = Color.FromArgb(217, 119, 87);
    var red = Color.FromArgb(239, 58, 58);
    bool small = s <= 48;
    int rays = tiny ? 7 : small ? 9 : 11;
    // Irregular lengths, like hand-drawn rays
    float[] lenPattern = tiny ? new[] { 0.55f, 0.45f } : new[] { 0.62f, 0.50f, 0.66f, 0.54f, 0.47f, 0.60f, 0.52f, 0.64f, 0.49f, 0.58f };
    float w0 = s * (tiny ? 0.075f : small ? 0.05f : 0.038f);   // width near the centre
    float w1 = s * (tiny ? 0.05f : small ? 0.032f : 0.024f);   // width at the tip
    using (var tb = new SolidBrush(terra)) {
      for (int i = 1; i < rays; i++) {
        float a = needleDeg + 360f * i / rays;
        Spoke(g, tb, cx, cy, r * 0.12f, r * lenPattern[(i - 1) % lenPattern.Length], w0, w1, a);
      }
    }
    // Needle ray: red, longer, a bit thicker at the base
    using (var nb = new SolidBrush(red))
      Spoke(g, nb, cx, cy, 0, r * (tiny ? 0.8f : 0.76f), w0 * 2.2f, w1 * 1.4f, needleDeg);
    // Small hub in terracotta so all rays meet in one point
    float hub = s * (tiny ? 0.07f : 0.05f);
    using (var hb = new SolidBrush(terra)) g.FillEllipse(hb, cx - hub, cy - hub, hub * 2, hub * 2);
    g.Dispose(); return bmp;
  }
  public static void SaveIco(string path, int[] sizes, string preview) {
    var pngs = new List<byte[]>();
    foreach (var s in sizes) using (var b = Draw(s)) using (var ms = new MemoryStream()) { b.Save(ms, System.Drawing.Imaging.ImageFormat.Png); pngs.Add(ms.ToArray()); }
    using (var fs = new FileStream(path, FileMode.Create)) using (var w = new BinaryWriter(fs)) {
      w.Write((short)0); w.Write((short)1); w.Write((short)sizes.Length);
      int offset = 6 + 16 * sizes.Length;
      for (int i = 0; i < sizes.Length; i++) {
        w.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i])); w.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i]));
        w.Write((byte)0); w.Write((byte)0); w.Write((short)1); w.Write((short)32);
        w.Write(pngs[i].Length); w.Write(offset); offset += pngs[i].Length;
      }
      foreach (var p in pngs) w.Write(p);
    }
    // Preview strip
    int total = 0; foreach (var s in sizes) total += s + 16;
    using (var strip = new Bitmap(total, 272)) using (var g = Graphics.FromImage(strip)) {
      g.Clear(Color.FromArgb(200, 200, 205)); int x = 8;
      foreach (var s in sizes) using (var b = Draw(s)) { g.DrawImage(b, x, 8, s, s); x += s + 16; }
      strip.Save(preview, System.Drawing.Imaging.ImageFormat.Png);
    }
  }
}
'@
[IconMaker]::SaveIco($OutIco, @(16, 20, 24, 32, 40, 48, 64, 128, 256), $PreviewPng)
"ok"
