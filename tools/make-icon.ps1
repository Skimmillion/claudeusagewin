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
    // Needle deep in the red zone
    float needleDeg = start + sweep * 0.9f;
    float len = r * (tiny ? 0.95f : 0.88f), baseW = s * (tiny ? 0.07f : 0.05f);
    var tip = P(cx, cy, len, needleDeg); var l = P(cx, cy, baseW, needleDeg - 90); var rr = P(cx, cy, baseW, needleDeg + 90);
    var back = P(cx, cy, baseW * 1.2f, needleDeg + 180);
    using (var path = new GraphicsPath()) {
      path.AddPolygon(new[] { tip, rr, back, l });
      using (var nb = new SolidBrush(Color.FromArgb(245, 245, 250))) g.FillPath(nb, path);
    }
    float hub = s * (tiny ? 0.1f : 0.075f);
    using (var hb = new SolidBrush(Color.FromArgb(245, 245, 250))) g.FillEllipse(hb, cx - hub, cy - hub, hub * 2, hub * 2);
    using (var hb2 = new SolidBrush(Color.FromArgb(239, 58, 58))) g.FillEllipse(hb2, cx - hub * 0.45f, cy - hub * 0.45f, hub * 0.9f, hub * 0.9f);
    if (!tiny) {
      // Ticks
      using (var tp = new Pen(Color.FromArgb(120, 255, 255, 255), Math.Max(1, s * 0.012f))) {
        tp.StartCap = tp.EndCap = LineCap.Round;
        for (int i = 0; i <= 10; i++) { float a = start + sweep * i / 10f; g.DrawLine(tp, P(cx, cy, r - thick * 0.95f, a), P(cx, cy, r - thick * (i % 5 == 0 ? 1.7f : 1.35f), a)); }
      }
      // Little flame at the bottom: "limit is burning"
      float fx = cx, fy = s * 0.9f, fh = s * 0.2f, fw = s * 0.13f;
      using (var flame = new GraphicsPath()) {
        flame.AddBezier(fx, fy, fx - fw, fy - fh * 0.15f, fx - fw * 0.75f, fy - fh * 0.65f, fx - fw * 0.1f, fy - fh);
        flame.AddBezier(fx - fw * 0.1f, fy - fh, fx + fw * 0.05f, fy - fh * 0.6f, fx + fw * 0.35f, fy - fh * 0.75f, fx + fw * 0.45f, fy - fh * 0.55f);
        flame.AddBezier(fx + fw * 0.45f, fy - fh * 0.55f, fx + fw * 1.0f, fy - fh * 0.3f, fx + fw * 0.8f, fy, fx, fy);
        using (var fb = new LinearGradientBrush(new PointF(0, fy - fh), new PointF(0, fy), Color.FromArgb(255, 220, 60), Color.FromArgb(239, 58, 58))) g.FillPath(fb, flame);
      }
    }
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
