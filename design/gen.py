# -*- coding: utf-8 -*-
"""產生 0.1 展示介面的版型比較 artboards。"""
from pathlib import Path

W, H = 1280, 800
C = dict(
    bg="#F4F6F5", surface="#FFFFFF", surf2="#E9EEED", surf3="#DCE4E2",
    line="#C7D2D0", line2="#E2E9E8",
    ink="#181C1B", ink2="#5C6866", ink3="#8A9694",
    pri="#2E6F6A", pri2="#E0EFED", priInk="#0F4B47",
    err="#B3261E", errBg="#FBE9E7", warn="#8A5A00", warnBg="#FBF1DF",
    ok="#2E6F3E",
)
FONT = '-apple-system, "SF Pro Text", "Helvetica Neue", system-ui, sans-serif'
MONO = '"SF Mono", ui-monospace, "JetBrains Mono", monospace'

def icon(d, size=16, color=None, fill="none"):
    col = color or C["ink2"]
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{fill}" '
            f'stroke="{col}" stroke-width="1.7" stroke-linecap="round" '
            f'stroke-linejoin="round" style="flex:none">{d}</svg>')

I = dict(
    folder='<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    grid='<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
    flow='<path d="M4 6h6M4 12h10M4 18h6"/><circle cx="18" cy="12" r="2.5"/>',
    trace='<path d="M12 3v6M12 15v6M5 12h14"/><circle cx="12" cy="12" r="2.5"/>',
    ticket='<path d="M4 6h16v4a2 2 0 0 0 0 4v4H4v-4a2 2 0 0 0 0-4z"/>',
    gap='<path d="M12 9v4M12 17h.01"/><path d="M10.3 4.3 2.6 18a2 2 0 0 0 1.7 3h15.4a2 2 0 0 0 1.7-3L13.7 4.3a2 2 0 0 0-3.4 0z"/>',
    doc='<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/>',
    chev='<path d="M9 6l6 6-6 6"/>',
    down='<path d="M6 9l6 6 6-6"/>',
    search='<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
)

NAV = [("grid","Domain"),("flow","UC Flow"),("trace","追溯"),
       ("ticket","Ticket"),("gap","破洞"),("doc","詳情")]

def shell(active, title, sub, body, toolbar=""):
    items = []
    for key, label in NAV:
        on = key == active
        items.append(
            f'<div style="display:flex;align-items:center;gap:9px;padding:7px 10px;'
            f'border-radius:8px;background:{C["pri2"] if on else "transparent"}">'
            f'{icon(I[key],17,C["priInk"] if on else C["ink2"])}'
            f'<span style="font-size:13px;color:{C["priInk"] if on else C["ink2"]};'
            f'font-weight:{600 if on else 450}">{label}</span></div>')
    nav = "".join(items)
    tb = (f'<div style="display:flex;align-items:center;gap:8px">{toolbar}</div>'
          if toolbar else "")
    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>
    body {{ margin:0; font-family:{FONT}; -webkit-font-smoothing:antialiased; }}
    a {{ color:{C["pri"]}; }} a:hover {{ color:{C["priInk"]}; }}
  </style>
</helmet>
<div style="width:{W}px;height:{H}px;background:{C['bg']};display:flex;
     flex-direction:column;overflow:hidden;color:{C['ink']}">
  <div style="height:36px;flex:none;background:{C['surf2']};
       border-bottom:1px solid {C['line']};display:flex;align-items:center;
       justify-content:center">
    <span style="font-size:12px;color:{C['ink2']};font-weight:500">專案文件流</span>
  </div>
  <div style="flex:1;display:flex;min-height:0">
    <div style="width:172px;flex:none;background:{C['surface']};
         border-right:1px solid {C['line2']};display:flex;flex-direction:column;
         gap:2px;padding:12px 10px">
      <div style="display:flex;align-items:center;gap:7px;padding:7px 9px;
           margin-bottom:8px;border-radius:8px;border:1px solid {C['line2']};
           background:{C['bg']}">
        {icon(I['folder'],15,C['ink2'])}
        <span style="flex:1;min-width:0;font-size:11.5px;font-weight:600;
              overflow:hidden;text-overflow:ellipsis;white-space:nowrap">flutter_balance</span>
        {icon(I['down'],13,C['ink3'])}
      </div>
      {nav}
    </div>
    <div style="flex:1;display:flex;flex-direction:column;min-width:0">
      <div style="height:52px;flex:none;padding:0 20px;display:flex;
           align-items:center;justify-content:space-between;
           border-bottom:1px solid {C['line2']};background:{C['surface']}">
        <div style="display:flex;flex-direction:column;gap:1px">
          <span style="font-size:15px;font-weight:600">{title}</span>
          <span style="font-size:11.5px;color:{C['ink3']}">{sub}</span>
        </div>
        {tb}
      </div>
      <div style="flex:1;min-height:0;overflow:hidden">{body}</div>
    </div>
  </div>
</div>
</x-dc>
</body>
</html>
"""

def btn(label, primary=False):
    if primary:
        return (f'<div style="padding:6px 13px;border-radius:7px;background:{C["pri"]};'
                f'font-size:12.5px;color:#fff;font-weight:550">{label}</div>')
    return (f'<div style="padding:6px 13px;border-radius:7px;border:1px solid {C["line"]};'
            f'background:{C["surface"]};font-size:12.5px;color:{C["ink2"]}">{label}</div>')

def seg(opts, idx):
    out = []
    for i, o in enumerate(opts):
        on = i == idx
        out.append(f'<div style="padding:5px 12px;border-radius:6px;font-size:12.5px;'
                   f'background:{C["surface"] if on else "transparent"};'
                   f'color:{C["priInk"] if on else C["ink2"]};font-weight:{600 if on else 450};'
                   f'{"box-shadow:0 1px 2px rgba(0,0,0,.08)" if on else ""}">{o}</div>')
    return (f'<div style="display:flex;gap:2px;padding:2px;border-radius:8px;'
            f'background:{C["surf3"]}">{"".join(out)}</div>')

def chip(text, bg, fg):
    return (f'<span style="padding:2px 7px;border-radius:5px;background:{bg};color:{fg};'
            f'font-size:10.5px;font-weight:600;white-space:nowrap">{text}</span>')

def pad(inner, p=20, gap=14, col=True):
    return (f'<div style="height:100%;padding:{p}px;display:flex;box-sizing:border-box;'
            f'flex-direction:{"column" if col else "row"};gap:{gap}px;'
            f'overflow:hidden">{inner}</div>')

def card(inner, grow=False, p=14):
    return (f'<div style="background:{C["surface"]};border:1px solid {C["line2"]};'
            f'border-radius:11px;padding:{p}px;{"flex:1;min-height:0;" if grow else ""}'
            f'display:flex;flex-direction:column;gap:10px;overflow:hidden">{inner}</div>')

Path(".").mkdir(exist_ok=True)
FILES = {}

DOMAINS = ["Workspace","Schema","Corpus","Graph","TicketDetail","Layout","Diagnostics"]
UCS = ["UC-01 開啟專案","UC-02 檢視穿透","UC-03 追溯需求","UC-04 檢視進度","UC-05 修復破洞"]
MTX = [  # ● 直接貫穿 ○ 間接依賴 · 無關
 [2,1,0,0,1],[2,2,0,0,1],[2,2,2,2,2],[1,2,2,2,2],
 [0,0,0,2,1],[0,2,1,1,0],[1,1,1,1,2],
]
DOTS = {2:("●",C["pri"]),1:("○",C["ink3"]),0:("·",C["line"])}

# ── Main：Domain 視圖 · 矩陣模式 ──────────────────────────
hdr = "".join(f'<div style="font-size:11px;color:{C["ink3"]};text-align:center;'
              f'padding:0 4px;line-height:1.25">{u.split(" ")[0]}<br>'
              f'<span style="font-size:10px">{u.split(" ")[1]}</span></div>' for u in UCS)
rows = []
for di, d in enumerate(DOMAINS):
    sel = d == "Corpus"
    cells = []
    for ui in range(len(UCS)):
        g, col = DOTS[MTX[di][ui]]
        cells.append(f'<div style="text-align:center;font-size:15px;color:{col};'
                     f'line-height:30px">{g}</div>')
    tot = sum(1 for v in MTX[di] if v == 2)
    rows.append(
      f'<div style="display:grid;grid-template-columns:132px repeat(5,1fr) 46px;'
      f'align-items:center;gap:0;height:32px;border-radius:7px;'
      f'background:{C["pri2"] if sel else "transparent"};padding:0 6px">'
      f'<span style="font-size:12.5px;font-weight:{600 if sel else 450};'
      f'color:{C["priInk"] if sel else C["ink"]}">{d}</span>{"".join(cells)}'
      f'<span style="font-size:11.5px;color:{C["ink3"]};text-align:right">{tot}</span></div>')
matrix = card(
  f'<div style="display:grid;grid-template-columns:132px repeat(5,1fr) 46px;'
  f'padding:0 6px 8px;border-bottom:1px solid {C["line2"]}"><div></div>{hdr}'
  f'<div style="font-size:11px;color:{C["ink3"]};text-align:right">小計</div></div>'
  f'<div style="display:flex;flex-direction:column;gap:1px">{"".join(rows)}</div>'
  f'<div style="display:flex;gap:16px;padding-top:8px;border-top:1px solid {C["line2"]};'
  f'font-size:11px;color:{C["ink3"]}">'
  f'<span style="color:{C["pri"]}">● 直接貫穿</span><span>○ 間接依賴</span>'
  f'<span>· 無關</span></div>', grow=True)
detail = card(
  f'<div style="font-size:12.5px;font-weight:600;color:{C["priInk"]}">Corpus × UC-02</div>'
  f'<div style="font-size:11px;color:{C["ink3"]};line-height:1.6">'
  f'唯一的解析者。三個消費方各自投影其產出。</div>'
  f'<div style="display:flex;flex-direction:column;gap:6px;margin-top:2px">' +
  "".join(f'<div style="display:flex;gap:7px;align-items:center">'
          f'<span style="width:16px;height:16px;border-radius:4px;background:{C["surf2"]};'
          f'font-size:9.5px;color:{C["ink3"]};display:flex;align-items:center;'
          f'justify-content:center;flex:none">{i+1}</span>'
          f'<span style="font-size:11.5px">{s}</span></div>'
          for i, s in enumerate(["掃描專案目錄","逐檔解析 frontmatter","容錯與斷點救援","發送 CorpusParsed"])) +
  f'</div>'
  f'<div style="margin-top:auto;display:flex;flex-wrap:wrap;gap:5px">'
  f'{chip("emits CorpusParsed", C["pri2"], C["priInk"])}'
  f'{chip("emits ParseFailed", C["errBg"], C["err"])}</div>')
FILES["Main.dc.html"] = shell(
  "grid", "Domain 視圖", "7 個 domain · 5 條 UC flow · 點格子切換至泳道",
  pad(f'<div style="display:flex;gap:14px;height:100%;min-height:0">'
      f'<div style="flex:1;min-width:0;display:flex">{matrix}</div>'
      f'<div style="width:236px;flex:none;display:flex">{detail}</div></div>'),
  seg(["矩陣","泳道"], 0))

# ── DomainSwimlane：泳道模式 ───────────────────────────
LANES = [("Workspace",[("選擇資料夾",0)]),("Schema",[("載入型別表",1)]),
         ("Corpus",[("掃描",2),("解析",3)]),("Graph",[("建圖",4)]),
         ("Layout",[("計算版面",5)]),("Diagnostics",[])]
lane_rows = []
for name, steps in LANES:
    hot = name in ("Corpus","Graph")
    cells = ['<div style="flex:1"></div>' for _ in range(6)]
    for label, pos in steps:
        cells[pos] = (
          f'<div style="flex:1;display:flex;justify-content:center"><div '
          f'style="padding:7px 10px;border-radius:8px;background:{C["pri"] if hot else C["surf2"]};'
          f'color:{"#fff" if hot else C["ink2"]};font-size:11.5px;font-weight:550;'
          f'white-space:nowrap">{label}</div></div>')
    lane_rows.append(
      f'<div style="display:flex;align-items:center;height:52px;'
      f'border-bottom:1px dashed {C["line2"]}">'
      f'<div style="width:106px;flex:none;font-size:12px;font-weight:{600 if hot else 450};'
      f'color:{C["priInk"] if hot else C["ink2"]}">{name}</div>'
      f'<div style="flex:1;display:flex;align-items:center">{"".join(cells)}</div></div>')
arrows = ('<div style="display:flex;align-items:center;height:16px">'
          '<div style="width:106px;flex:none"></div>' +
          "".join(f'<div style="flex:1;display:flex;justify-content:center">'
                  f'{icon(I["chev"],13,C["line"])}</div>' for _ in range(6)) + '</div>')
FILES["DomainSwimlane.dc.html"] = shell(
  "grid", "Domain 視圖", "UC-02 檢視穿透 · 貫穿 4 個 domain",
  pad(card(
    f'<div style="font-size:12.5px;font-weight:600">UC-02 檢視穿透</div>'
    f'<div style="flex:1;min-height:0;display:flex;flex-direction:column;'
    f'justify-content:center">{"".join(lane_rows)}{arrows}</div>'
    f'<div style="display:flex;gap:6px;padding-top:6px;border-top:1px solid {C["line2"]}">'
    f'{chip("選中 domain 高亮", C["pri2"], C["priInk"])}'
    f'{chip("虛線 = 未參與", C["surf2"], C["ink3"])}</div>', grow=True)),
  seg(["矩陣","泳道"], 1))
print(f"batch1: {len(FILES)}")

PROJS = [("flutter_balance","~/project/flutter_balance",16,1338,130,"2 分鐘前"),
         ("book_overview_app","~/project/book_overview_app",189,1528,1,"昨天"),
         ("book_overview_v1","~/project/book_overview_v1",237,2419,0,"上週"),
         ("monitor","~/project/monitor",49,207,0,"3 週前"),
         ("screen_clock","~/project/screen_clock",25,175,0,"上個月")]

# ── ProjectPicker A：清單 + 預覽 ──────────────────────
lst = []
for i,(n,p,nd,tk,gp,t) in enumerate(PROJS):
    on = i == 0
    lst.append(
      f'<div style="display:flex;align-items:center;gap:10px;padding:9px 11px;'
      f'border-radius:8px;background:{C["pri2"] if on else "transparent"}">'
      f'{icon(I["folder"],17,C["priInk"] if on else C["ink3"])}'
      f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:1px">'
      f'<span style="font-size:12.5px;font-weight:{600 if on else 500};'
      f'color:{C["priInk"] if on else C["ink"]}">{n}</span>'
      f'<span style="font-size:10.5px;color:{C["ink3"]};font-family:{MONO}">{p}</span></div>'
      f'<span style="font-size:10.5px;color:{C["ink3"]};flex:none">{t}</span></div>')
prev = card(
  f'<div style="font-size:13px;font-weight:600">flutter_balance</div>'
  f'<div style="font-size:11px;color:{C["ink3"]};font-family:{MONO}">'
  f'~/project/flutter_balance</div>'
  f'<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:9px;margin-top:4px">' +
  "".join(f'<div style="background:{bg};border-radius:9px;padding:11px 10px;'
          f'display:flex;flex-direction:column;gap:2px">'
          f'<span style="font-size:19px;font-weight:700;color:{fg}">{v}</span>'
          f'<span style="font-size:10.5px;color:{C["ink3"]}">{k}</span></div>'
          for v,k,bg,fg in [("16","圖譜節點",C["surf2"],C["ink"]),
                            ("1338","Ticket",C["surf2"],C["ink"]),
                            ("130","損壞",C["errBg"],C["err"])]) +
  f'</div>'
  f'<div style="margin-top:6px;padding:10px 11px;border-radius:9px;background:{C["errBg"]};'
  f'display:flex;gap:9px;align-items:flex-start">{icon(I["gap"],15,C["err"])}'
  f'<span style="font-size:11.5px;color:{C["err"]};line-height:1.55">'
  f'130 張 ticket 的 frontmatter 含未閉合引號，<code style="font-family:{MONO}">acceptance</code>'
  f' 欄位無法讀取</span></div>'
  f'<div style="margin-top:auto;display:flex;gap:8px">{btn("開啟專案",True)}'
  f'{btn("選擇其他資料夾")}</div>', grow=True)
FILES["ProjectPickerA.dc.html"] = shell("folder","選擇專案","方案 A · 清單與健康摘要並列",
  pad(f'<div style="display:flex;gap:14px;height:100%;min-height:0">'
      f'<div style="width:400px;flex:none;display:flex">'
      f'{card(f"<div style=\'display:flex;flex-direction:column;gap:2px\'>{chr(10).join(lst)}</div>", grow=True)}</div>'
      f'<div style="flex:1;min-width:0;display:flex">{prev}</div></div>'))

# ── ProjectPicker B：卡片格狀 ─────────────────────────
cards = []
for n,p,nd,tk,gp,t in PROJS:
    bad = gp > 0
    cards.append(
      f'<div style="background:{C["surface"]};border:1px solid {C["errBg"] if bad else C["line2"]};'
      f'border-radius:11px;padding:14px;display:flex;flex-direction:column;gap:9px">'
      f'<div style="display:flex;align-items:center;gap:8px">'
      f'{icon(I["folder"],17,C["pri"])}'
      f'<span style="font-size:12.5px;font-weight:600;flex:1;min-width:0;'
      f'overflow:hidden;text-overflow:ellipsis;white-space:nowrap">{n}</span></div>'
      f'<div style="display:flex;gap:12px">'
      f'<span style="font-size:11px;color:{C["ink3"]}">節點 <b style="color:{C["ink"]}">{nd}</b></span>'
      f'<span style="font-size:11px;color:{C["ink3"]}">票 <b style="color:{C["ink"]}">{tk}</b></span></div>'
      f'{chip(f"{gp} 處損壞", C["errBg"], C["err"]) if bad else chip("結構完整", C["pri2"], C["priInk"])}'
      f'<span style="font-size:10.5px;color:{C["ink3"]};margin-top:auto">{t}</span></div>')
addc = (f'<div style="border:1.5px dashed {C["line"]};border-radius:11px;padding:14px;'
        f'display:flex;flex-direction:column;align-items:center;justify-content:center;'
        f'gap:8px;min-height:118px">{icon(I["folder"],22,C["ink3"])}'
        f'<span style="font-size:12px;color:{C["ink2"]};font-weight:550">選擇工作資料夾</span>'
        f'<span style="font-size:10.5px;color:{C["ink3"]};text-align:center;'
        f'line-height:1.5">或將資料夾拖曳至此</span></div>')
FILES["ProjectPickerB.dc.html"] = shell("folder","選擇專案","方案 B · 卡片格狀與健康徽章",
  pad(f'<div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));'
      f'gap:14px;align-content:start">{"".join(cards)}{addc}</div>'))
print(f"batch2: {len(FILES)}")

STEPS = [("選擇資料夾","Workspace","WorkspaceSelected",""),
         ("載入型別表","Schema","SchemaLoaded",""),
         ("掃描目錄","Corpus","",""),
         ("解析 frontmatter","Corpus","CorpusParsed","ParseFailed"),
         ("建圖與 union","Graph","GraphBuilt",""),
         ("計算版面","Layout","LayoutComputed","")]

# ── UCFlow A：水平時間軸 ─────────────────────────────
nodes = []
for i,(lbl,dom,em,er) in enumerate(STEPS):
    nodes.append(
      f'<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:7px">'
      f'<div style="font-size:10px;color:{C["ink3"]};font-weight:600">{dom}</div>'
      f'<div style="width:100%;padding:11px 8px;border-radius:9px;background:{C["surface"]};'
      f'border:1.5px solid {C["pri"] if er else C["line2"]};text-align:center">'
      f'<div style="font-size:11.5px;font-weight:550;line-height:1.35">{lbl}</div></div>'
      f'{chip(em, C["pri2"], C["priInk"]) if em else ""}'
      f'{chip(er, C["errBg"], C["err"]) if er else ""}</div>')
    if i < len(STEPS)-1:
        nodes.append(f'<div style="flex:none;padding-top:26px">{icon(I["chev"],15,C["line"])}</div>')
FILES["UCFlowA.dc.html"] = shell("flow","UC Flow 視圖","方案 A · 水平時間軸，事件掛在步驟下",
  pad(card(
    f'<div style="font-size:12.5px;font-weight:600">UC-02 檢視穿透</div>'
    f'<div style="flex:1;min-height:0;display:flex;align-items:center;gap:4px">'
    f'{"".join(nodes)}</div>'
    f'<div style="display:flex;gap:6px;padding-top:8px;border-top:1px solid {C["line2"]}">'
    f'{chip("emits", C["pri2"], C["priInk"])}{chip("失敗路徑", C["errBg"], C["err"])}</div>',
    grow=True)))

# ── UCFlow B：垂直步驟 + domain 標籤 ──────────────────
vrows = []
for i,(lbl,dom,em,er) in enumerate(STEPS):
    vrows.append(
      f'<div style="display:grid;grid-template-columns:26px 1fr 118px 1fr;'
      f'align-items:center;gap:12px;padding:9px 0;'
      f'border-bottom:1px solid {C["line2"]}">'
      f'<span style="width:24px;height:24px;border-radius:12px;background:{C["pri2"]};'
      f'color:{C["priInk"]};font-size:11px;font-weight:600;display:flex;'
      f'align-items:center;justify-content:center">{i+1}</span>'
      f'<span style="font-size:12.5px;font-weight:500">{lbl}</span>'
      f'<span style="font-size:11.5px;color:{C["priInk"]};background:{C["pri2"]};'
      f'padding:3px 8px;border-radius:6px;text-align:center;font-weight:550">{dom}</span>'
      f'<div style="display:flex;gap:5px;flex-wrap:wrap">'
      f'{chip("emits "+em, C["surf2"], C["ink2"]) if em else ""}'
      f'{chip("emits "+er, C["errBg"], C["err"]) if er else ""}</div></div>')
FILES["UCFlowB.dc.html"] = shell("flow","UC Flow 視圖","方案 B · 垂直步驟，domain 與事件成欄",
  pad(card(
    f'<div style="display:grid;grid-template-columns:26px 1fr 118px 1fr;gap:12px;'
    f'padding-bottom:7px;border-bottom:1px solid {C["line"]};font-size:10.5px;'
    f'color:{C["ink3"]};font-weight:600"><span></span><span>步驟</span>'
    f'<span style="text-align:center">Domain</span><span>發送事件</span></div>'
    f'<div style="flex:1;min-height:0;overflow:hidden">{"".join(vrows)}</div>', grow=True)))

# ── Trace A：樹狀展開 ────────────────────────────────
TREE = [(0,"PROP-001 交付形態與發布通路","confirmed",C["ok"]),
        (1,"SPEC-001 沙盒與 entitlements 契約","approved",C["ok"]),
        (2,"UC-01 開啟專案","—",C["ink3"]),
        (3,"0.1.0-W1-003 關閉 App Sandbox","completed",C["ok"]),
        (3,"0.1.0-W1-004 契約測試斷言反轉","completed",C["ok"]),
        (0,"PROP-002 圖譜 schema 消費方式","confirmed",C["ok"]),
        (1,"SPEC-002 schema 載入與版本相容","draft",C["warn"]),
        (2,"UC-02 檢視穿透","—",C["ink3"]),
        (3,"（尚無 ticket）","缺口",C["err"])]
tr = []
for depth,label,st,col in TREE:
    tr.append(
      f'<div style="display:flex;align-items:center;gap:8px;height:31px;'
      f'padding-left:{depth*24}px">'
      f'{icon(I["down"] if depth<3 else I["chev"],13,C["ink3"])}'
      f'<span style="font-size:12px;font-weight:{600 if depth==0 else 450};'
      f'flex:1;min-width:0">{label}</span>'
      f'<span style="font-size:10.5px;color:{col};font-weight:600">{st}</span></div>')
FILES["TraceA.dc.html"] = shell("trace","追溯視圖","方案 A · 樹狀展開，沿因果鏈往下",
  pad(card(f'<div style="flex:1;min-height:0">{"".join(tr)}</div>', grow=True)))

# ── Trace B：四欄漏斗 ────────────────────────────────
COLS = [("PROP",[("PROP-001",1),("PROP-002",1),("PROP-003",0),("PROP-004",0)]),
        ("SPEC",[("SPEC-001",1),("SPEC-002",1)]),
        ("UC",[("UC-01",0),("UC-02",1)]),
        ("Ticket",[("W1-003",0),("W1-004",0),("(缺口)",-1)])]
cols = []
for title, items in COLS:
    its = []
    for name, on in items:
        if on == -1:
            its.append(f'<div style="padding:8px 10px;border-radius:8px;'
                       f'border:1.5px dashed {C["err"]};font-size:11.5px;'
                       f'color:{C["err"]};text-align:center">{name}</div>')
        else:
            its.append(f'<div style="padding:8px 10px;border-radius:8px;'
                       f'background:{C["pri"] if on else C["surf2"]};'
                       f'color:{"#fff" if on else C["ink2"]};font-size:11.5px;'
                       f'font-weight:{600 if on else 450};font-family:{MONO}">{name}</div>')
    cols.append(f'<div style="flex:1;display:flex;flex-direction:column;gap:8px">'
                f'<div style="font-size:11px;color:{C["ink3"]};font-weight:600;'
                f'text-align:center;padding-bottom:6px;border-bottom:1px solid {C["line2"]}">'
                f'{title}</div>{"".join(its)}</div>')
    if title != "Ticket":
        cols.append(f'<div style="flex:none;display:flex;align-items:center;'
                    f'padding-top:30px">{icon(I["chev"],15,C["line"])}</div>')
FILES["TraceB.dc.html"] = shell("trace","追溯視圖","方案 B · 四欄漏斗，高亮選中鏈路",
  pad(card(f'<div style="flex:1;min-height:0;display:flex;gap:12px;'
           f'align-items:flex-start">{"".join(cols)}</div>'
           f'<div style="padding-top:8px;border-top:1px solid {C["line2"]};'
           f'font-size:11px;color:{C["ink3"]}">選中 PROP-002 → 高亮其下游鏈路；'
           f'虛線框代表該層缺口</div>', grow=True)))
print(f"batch3: {len(FILES)}")

TIX = [("0.2.1-W3-1113","上游產出 tracking_schema.json","completed",C["ok"],"P1"),
       ("0.2.1-W3-1115","where.layer 值域處置評估","pending",C["warn"],"P2"),
       ("0.2.1-W3-1117","doc create --title 不寫入檔案","pending",C["warn"],"P3"),
       ("0.0.2-W1-002","doc update status 誤報","pending",C["err"],"P1"),
       ("0.2.1-W3-740","調整註冊時機或加回滾","completed",C["ok"],"P2"),
       ("0.1.0-W2-007","遷移 calculations.dart 至 lib/domain","completed",C["ok"],"P2"),
       ("0.2.1-W3-1114","commit 層偵測 JSON 過期","pending",C["warn"],"P2")]

# ── TicketList A：密集表格 + 虛擬捲動 ──────────────────
trows = []
for tid, title, st, col, pri in TIX:
    dmg = tid == "0.2.1-W3-740"
    trows.append(
      f'<div style="display:grid;grid-template-columns:132px 1fr 84px 40px 22px;'
      f'align-items:center;gap:12px;height:34px;padding:0 10px;'
      f'border-bottom:1px solid {C["line2"]}">'
      f'<span style="font-size:11px;font-family:{MONO};color:{C["ink2"]}">{tid}</span>'
      f'<span style="font-size:12px;overflow:hidden;text-overflow:ellipsis;'
      f'white-space:nowrap">{title}</span>'
      f'<span style="font-size:10.5px;color:{col};font-weight:600">{st}</span>'
      f'<span style="font-size:10.5px;color:{C["ink3"]}">{pri}</span>'
      f'<span>{icon(I["gap"],13,C["err"]) if dmg else ""}</span></div>')
FILES["TicketListA.dc.html"] = shell("ticket","Ticket 清單","方案 A · 密集表格與虛擬捲動",
  pad(card(
    f'<div style="display:flex;gap:8px;align-items:center;padding-bottom:10px;'
    f'border-bottom:1px solid {C["line"]}">'
    f'<div style="flex:1;display:flex;align-items:center;gap:7px;padding:5px 10px;'
    f'border-radius:7px;background:{C["surf2"]}">{icon(I["search"],14,C["ink3"])}'
    f'<span style="font-size:11.5px;color:{C["ink3"]}">搜尋 ticket…</span></div>'
    f'{btn("狀態：全部")}{btn("Wave：W3")}</div>'
    f'<div style="display:grid;grid-template-columns:132px 1fr 84px 40px 22px;gap:12px;'
    f'padding:0 10px 6px;font-size:10.5px;color:{C["ink3"]};font-weight:600">'
    f'<span>ID</span><span>標題</span><span>狀態</span><span>優先</span><span></span></div>'
    f'<div style="flex:1;min-height:0;overflow:hidden">{"".join(trows)}</div>'
    f'<div style="display:flex;justify-content:space-between;align-items:center;'
    f'padding-top:9px;border-top:1px solid {C["line2"]};font-size:11px;color:{C["ink3"]}">'
    f'<span>顯示 1–7，共 <b style="color:{C["ink"]}">1338</b> 筆'
    f'（<span style="color:{C["err"]}">130 筆資料損壞</span>）</span>'
    f'<span>虛擬捲動，不分頁</span></div>', grow=True)),
  toolbar=btn("匯出"))

# ── TicketList B：分組摺疊 ───────────────────────────
GRP = [("W3 · 進行中", 42, True, TIX[:4]), ("W2 · 已完成", 318, False, []),
       ("W1 · 已完成", 976, False, []), ("未分派", 2, False, [])]
grps = []
for name, cnt, open_, items in GRP:
    body = ""
    if open_:
        body = "".join(
          f'<div style="display:flex;align-items:center;gap:10px;height:32px;'
          f'padding:0 12px 0 30px;border-top:1px solid {C["line2"]}">'
          f'<span style="font-size:11px;font-family:{MONO};color:{C["ink3"]};'
          f'width:126px;flex:none">{t}</span>'
          f'<span style="font-size:12px;flex:1;min-width:0;overflow:hidden;'
          f'text-overflow:ellipsis;white-space:nowrap">{ti}</span>'
          f'<span style="font-size:10.5px;color:{c};font-weight:600">{s}</span></div>'
          for t, ti, s, c, _ in items)
    grps.append(
      f'<div style="border:1px solid {C["line2"]};border-radius:10px;overflow:hidden;'
      f'background:{C["surface"]}">'
      f'<div style="display:flex;align-items:center;gap:9px;height:40px;padding:0 12px;'
      f'background:{C["surf2"] if open_ else C["surface"]}">'
      f'{icon(I["down"] if open_ else I["chev"],14,C["ink2"])}'
      f'<span style="font-size:12.5px;font-weight:600;flex:1">{name}</span>'
      f'<span style="font-size:11px;color:{C["ink3"]}">{cnt} 筆</span></div>{body}</div>')
FILES["TicketListB.dc.html"] = shell("ticket","Ticket 清單","方案 B · 依 Wave 分組摺疊",
  pad(f'<div style="display:flex;flex-direction:column;gap:10px">{"".join(grps)}'
      f'<div style="font-size:11px;color:{C["ink3"]};padding:2px 4px">'
      f'共 1338 筆 · 展開一組才載入該組明細</div></div>'))

# ── GapReport A：分類清單 ────────────────────────────
GAPS = [("資料損壞", C["err"], C["errBg"], [
          ("130 張 ticket 的 frontmatter 未閉合引號","acceptance 欄位全數無法讀取"),
          ("4 個檔案缺少 frontmatter","不進入圖譜")]),
        ("追溯缺口", C["warn"], C["warnBg"], [
          ("PROP-002 尚無對應 ticket","規格已 confirmed 但未展開"),
          ("UC-02 無對應測試","traceability 矩陣該列為空")]),
        ("圖結構", C["ink2"], C["surf2"], [
          ("3 條邊指向不存在的節點","relatedTo 指向已刪除的 SPEC")])]
secs = []
for name, col, bg, items in GAPS:
    rows = "".join(
      f'<div style="display:flex;gap:10px;align-items:flex-start;padding:9px 0;'
      f'border-top:1px solid {C["line2"]}">'
      f'<div style="flex:1;display:flex;flex-direction:column;gap:2px">'
      f'<span style="font-size:12px;font-weight:500">{t}</span>'
      f'<span style="font-size:11px;color:{C["ink3"]}">{d}</span></div>'
      f'{icon(I["chev"],14,C["ink3"])}</div>' for t, d in items)
    secs.append(
      f'<div style="display:flex;flex-direction:column">'
      f'<div style="display:flex;align-items:center;gap:8px;padding-bottom:7px">'
      f'{chip(name, bg, col)}'
      f'<span style="font-size:11px;color:{C["ink3"]}">{len(items)} 類</span></div>'
      f'{rows}</div>')
FILES["GapReportA.dc.html"] = shell("gap","破洞報告","方案 A · 依類別分節，可直接跳轉修復",
  pad(card(f'<div style="flex:1;min-height:0;display:flex;flex-direction:column;'
           f'gap:16px">{"".join(secs)}</div>', grow=True)))

# ── GapReport B：儀表板鑽取 ──────────────────────────
KPI = [("134","資料損壞",C["err"],C["errBg"]),("2","追溯缺口",C["warn"],C["warnBg"]),
       ("3","斷邊",C["ink2"],C["surf2"]),("94%","可解析率",C["ok"],C["pri2"])]
kpis = "".join(
  f'<div style="flex:1;background:{bg};border-radius:11px;padding:14px;'
  f'display:flex;flex-direction:column;gap:3px">'
  f'<span style="font-size:24px;font-weight:700;color:{fg}">{v}</span>'
  f'<span style="font-size:11px;color:{C["ink2"]}">{k}</span></div>'
  for v, k, fg, bg in KPI)
drill = "".join(
  f'<div style="display:flex;align-items:center;gap:10px;height:36px;'
  f'border-bottom:1px solid {C["line2"]}">'
  f'<span style="font-size:11px;font-family:{MONO};color:{C["ink3"]};'
  f'width:150px;flex:none">{p}</span>'
  f'<span style="font-size:12px;flex:1">{m}</span>'
  f'<span style="font-size:10.5px;color:{C["ink3"]};font-family:{MONO}">行 {ln}</span></div>'
  for p, m, ln in [("0.2.1-W3-740.md","未閉合的單引號字串","38"),
                   ("0.2.1-W3-741.md","未閉合的單引號字串","36"),
                   ("0.2.1-W3-742.md","未閉合的單引號字串","41"),
                   ("v0.1/index.md","缺少 frontmatter","—")])
FILES["GapReportB.dc.html"] = shell("gap","破洞報告","方案 B · 指標卡片與鑽取明細",
  pad(f'<div style="display:flex;gap:12px">{kpis}</div>'
      + card(f'<div style="font-size:12.5px;font-weight:600">資料損壞 · 前 4 筆</div>'
             f'{drill}'
             f'<div style="margin-top:auto;font-size:11px;color:{C["ink3"]}">'
             f'點列開啟原始檔並定位至該行</div>', grow=True)))
print(f"batch4: {len(FILES)}")

# ── NodeDetail A：側欄抽屜（主視圖仍可見）─────────────
ghost = (f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:9px;'
         f'opacity:.42;pointer-events:none">' +
         "".join(f'<div style="display:grid;grid-template-columns:120px repeat(4,1fr);'
                 f'gap:8px;height:28px;align-items:center">'
                 f'<span style="font-size:11.5px">{d}</span>' +
                 "".join('<div style="text-align:center;font-size:14px;color:%s">%s</div>'
                         % (C["pri"] if (i+j) % 3 else C["line"], "●" if (i+j) % 3 else "·")
                         for j in range(4)) + '</div>'
                 for i, d in enumerate(DOMAINS[:6])) + '</div>')
drawer_body = (
  f'<div style="display:flex;align-items:center;gap:8px">'
  f'{chip("SPEC", C["pri2"], C["priInk"])}'
  f'<span style="font-size:11px;color:{C["ink3"]};font-family:{MONO}">SPEC-002</span></div>'
  f'<div style="font-size:14px;font-weight:600;line-height:1.4">'
  f'schema 載入與版本相容判定</div>'
  f'<div style="display:flex;gap:6px;flex-wrap:wrap">'
  f'{chip("draft", C["warnBg"], C["warn"])}{chip("domain: schema", C["surf2"], C["ink2"])}</div>'
  f'<div style="height:1px;background:{C["line2"]}"></div>'
  + "".join(f'<div style="display:flex;flex-direction:column;gap:4px">'
            f'<span style="font-size:10.5px;color:{C["ink3"]};font-weight:600">{k}</span>'
            + "".join(f'<div style="display:flex;align-items:center;gap:7px">'
                      f'{icon(I["chev"],12,C["ink3"])}'
                      f'<span style="font-size:11.5px;font-family:{MONO}">{v}</span></div>'
                      for v in vs) + '</div>'
            for k, vs in [("source_proposal", ["PROP-002"]),
                          ("related_usecases", ["UC-02 檢視穿透"]),
                          ("implements_requirements", ["FR-08", "FR-09"])])
  + f'<div style="margin-top:auto;display:flex;gap:8px">{btn("開啟原始檔", True)}</div>')
FILES["NodeDetailA.dc.html"] = shell("doc","節點詳情","方案 A · 右側抽屜，主視圖保持可見",
  pad(f'<div style="display:flex;gap:14px;height:100%;min-height:0">'
      f'{card(ghost, grow=True)}'
      f'<div style="width:304px;flex:none;display:flex;'
      f'box-shadow:-6px 0 18px rgba(0,0,0,.06)">{card(drawer_body, grow=True)}</div></div>'))

# ── NodeDetail B：全頁 + 關聯側邊 ─────────────────────
main_body = (
  f'<div style="display:flex;align-items:center;gap:8px">'
  f'{chip("SPEC", C["pri2"], C["priInk"])}'
  f'<span style="font-size:11px;color:{C["ink3"]};font-family:{MONO}">'
  f'docs/spec/schema/loading.md</span></div>'
  f'<div style="font-size:19px;font-weight:650;line-height:1.35">'
  f'schema 載入與版本相容判定</div>'
  f'<div style="display:flex;gap:6px">{chip("draft", C["warnBg"], C["warn"])}'
  f'{chip("domain: schema", C["surf2"], C["ink2"])}'
  f'{chip("2 個 FR", C["surf2"], C["ink2"])}</div>'
  f'<div style="height:1px;background:{C["line2"]};margin:2px 0"></div>'
  f'<div style="font-size:12.5px;line-height:1.85;color:{C["ink2"]}">'
  f'自使用者專案載入 <code style="font-family:{MONO};background:{C["surf2"]};'
  f'padding:1px 5px;border-radius:4px">tracking_schema.json</code>，'
  f'建立節點與邊的型別模型。版本超出已知範圍時明確拒絕，不靜默降級——'
  f'渲染可能錯誤的圖比拒絕更糟，使用者無從分辨圖是對的還是壞的。</div>'
  f'<div style="background:{C["surf2"]};border-radius:9px;padding:12px;'
  f'display:flex;flex-direction:column;gap:6px">'
  f'<span style="font-size:10.5px;color:{C["ink3"]};font-weight:600">'
  f'FR-08 · 版本相容判定</span>'
  f'<span style="font-size:11.5px;line-height:1.7">讀取 '
  f'<code style="font-family:{MONO}">.claude/VERSION</code> 判定使用者框架版本；'
  f'讀取 JSON 內 <code style="font-family:{MONO}">schema_generated_at_'
  f'framework_version</code> 判定 schema 變動時點。兩者語意不同，不可混用。</span></div>')
side = "".join(
  f'<div style="display:flex;flex-direction:column;gap:6px">'
  f'<span style="font-size:10.5px;color:{C["ink3"]};font-weight:600">{k}</span>'
  + "".join(f'<div style="padding:7px 9px;border-radius:7px;background:{C["surf2"]};'
            f'font-size:11.5px;font-family:{MONO}">{v}</div>' for v in vs) + '</div>'
  for k, vs in [("source_proposal", ["PROP-002"]),
                ("related_usecases", ["UC-02"]),
                ("implements", ["FR-08", "FR-09"]),
                ("被引用於", ["EVT-SCHEMA-001", "EVT-SCHEMA-002"])])
FILES["NodeDetailB.dc.html"] = shell("doc","節點詳情","方案 B · 全頁內容，關聯收在右欄",
  pad(f'<div style="display:flex;gap:14px;height:100%;min-height:0">'
      f'{card(main_body, grow=True, p=18)}'
      f'<div style="width:216px;flex:none;display:flex">'
      f'{card(side, grow=True)}</div></div>'))

# ── TicketList A：列表模式（加入模式切換）──────────────
FILES["TicketListA.dc.html"] = shell("ticket","Ticket 清單","列表模式 · 密集表格與虛擬捲動",
  pad(card(
    f'<div style="display:flex;gap:8px;align-items:center;padding-bottom:10px;'
    f'border-bottom:1px solid {C["line"]}">'
    f'<div style="flex:1;display:flex;align-items:center;gap:7px;padding:5px 10px;'
    f'border-radius:7px;background:{C["surf2"]}">{icon(I["search"],14,C["ink3"])}'
    f'<span style="font-size:11.5px;color:{C["ink3"]}">搜尋 ticket…</span></div>'
    f'{btn("狀態：pending")}{btn("優先：全部")}</div>'
    f'<div style="display:grid;grid-template-columns:132px 1fr 84px 40px 22px;gap:12px;'
    f'padding:0 10px 6px;font-size:10.5px;color:{C["ink3"]};font-weight:600">'
    f'<span>ID</span><span>標題</span><span>狀態</span><span>優先</span><span></span></div>'
    f'<div style="flex:1;min-height:0;overflow:hidden">{"".join(trows)}</div>'
    f'<div style="display:flex;justify-content:space-between;align-items:center;'
    f'padding-top:9px;border-top:1px solid {C["line2"]};font-size:11px;color:{C["ink3"]}">'
    f'<span>顯示 1–7，共 <b style="color:{C["ink"]}">1338</b> 筆'
    f'（<span style="color:{C["err"]}">130 筆資料損壞</span>）</span>'
    f'<span>虛擬捲動，不分頁</span></div>', grow=True)),
  toolbar=seg(["列表","群組"], 0))

# ── TicketList B：並行群組（ticket track --groups）─────
def gsec(title, sub, items, col, bg, dashed=False):
    rows = "".join(
      f'<div style="display:flex;align-items:center;gap:10px;height:31px;'
      f'padding:0 11px;border-radius:7px;background:{bg}">'
      f'<span style="font-size:11px;font-family:{MONO};width:126px;flex:none;'
      f'color:{col};font-weight:600">{t}</span>'
      f'<span style="font-size:11.5px;flex:1;min-width:0;overflow:hidden;'
      f'text-overflow:ellipsis;white-space:nowrap;color:{C["ink2"]}">{d}</span>'
      f'<span style="font-size:10.5px;color:{C["ink3"]};font-family:{MONO};'
      f'flex:none">{f}</span></div>' for t, d, f in items)
    return (f'<div style="display:flex;flex-direction:column;gap:5px">'
            f'<div style="display:flex;align-items:baseline;gap:8px">'
            f'<span style="font-size:12px;font-weight:600;color:{col}">{title}</span>'
            f'<span style="font-size:10.5px;color:{C["ink3"]}">{sub}</span></div>'
            f'<div style="display:flex;flex-direction:column;gap:3px;'
            f'{"border:1.5px dashed "+C["line"]+";border-radius:9px;padding:5px" if dashed else ""}">'
            f'{rows}</div></div>')

FILES["TicketListB.dc.html"] = shell("ticket","Ticket 清單","群組模式 · 依 where.files 交集切出可並行集合",
  pad(card(
    gsec("可並行群組", "4 票，兩兩無交集，可同時派發", [
      ("0.2.1-W3-1113","上游產出 tracking_schema.json","core/"),
      ("0.2.1-W3-1115","where.layer 值域處置評估","docs/"),
      ("0.2.1-W3-1117","doc create --title 不寫入檔案","commands/create.py"),
      ("0.0.2-W1-002","doc update status 誤報","commands/update.py")],
      C["priInk"], C["pri2"])
    + gsec("本輪未選入", "1 票，與已選票有檔案交集", [
      ("0.2.1-W3-1114","commit 層偵測 JSON 過期","core/, hooks/")],
      C["warn"], C["warnBg"])
    + gsec("施工中佔用節點", "1 票，in_progress 且非 stale，僅提供衝突邊", [
      ("0.2.1-W3-740","調整註冊時機或加回滾","hooks/dispatch-*")],
      C["ink2"], C["surf2"], dashed=True)
    + f'<div style="margin-top:auto;padding-top:10px;border-top:1px solid {C["line2"]};'
      f'display:flex;flex-direction:column;gap:5px">'
      f'<span style="font-size:10.5px;color:{C["ink3"]};font-weight:600">衝突對（2 組）</span>'
    + "".join(f'<div style="display:flex;gap:8px;align-items:baseline">'
              f'<span style="font-size:10.5px;font-family:{MONO};color:{C["ink2"]}">{a}</span>'
              f'<span style="font-size:10.5px;color:{C["ink3"]}">↔</span>'
              f'<span style="font-size:10.5px;font-family:{MONO};color:{C["ink2"]}">{b}</span>'
              f'{chip("heuristic", C["surf2"], C["ink3"]) if h else ""}'
              f'<span style="font-size:10.5px;color:{C["ink3"]};font-family:{MONO}">{p}</span></div>'
              for a,b,h,p in [("0.2.1-W3-1114","0.2.1-W3-1113",False,"core/tracking_schema.json"),
                              ("0.2.1-W3-740","0.2.1-W3-1114",True,"hooks/tests/")])
    + '</div>', grow=True)),
  toolbar=seg(["列表","群組"], 1))

# ── UCFlow C：事件匯流排 ─────────────────────────────
BUS = [("Workspace",[("WorkspaceSelected","up")]),
       ("Schema",[("WorkspaceSelected","down"),("SchemaLoaded","up")]),
       ("Corpus",[("SchemaLoaded","down"),("CorpusParsed","up")]),
       ("Graph",[("CorpusParsed","down"),("GraphBuilt","up")]),
       ("Layout",[("GraphBuilt","down")])]
lanes_up, bus_evts, lanes_dn = [], [], []
for name, evts in BUS:
    ups = [e for e,d in evts if d=="up"]
    lanes_up.append(
      f'<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px">'
      f'<div style="padding:9px 12px;border-radius:9px;background:{C["surface"]};'
      f'border:1.5px solid {C["line"]};font-size:11.5px;font-weight:550;'
      f'white-space:nowrap">{name}</div>'
      f'<div style="width:1.5px;height:14px;background:{C["pri"] if ups else C["line2"]}"></div>'
      f'</div>')
for name, evts in BUS:
    ups = [e for e,d in evts if d=="up"]
    bus_evts.append(
      f'<div style="flex:1;display:flex;justify-content:center">'
      + (f'{chip(ups[0], C["pri"], "#fff")}' if ups else
         f'<span style="font-size:10px;color:{C["line"]}">—</span>') + '</div>')
FILES["UCFlowC.dc.html"] = shell("flow","UC Flow 視圖","方案 C · 事件匯流排，強調 domain 之間傳遞的是事實",
  pad(card(
    f'<div style="font-size:12.5px;font-weight:600">UC-02 檢視穿透</div>'
    f'<div style="flex:1;min-height:0;display:flex;flex-direction:column;'
    f'justify-content:center;gap:0">'
    f'<div style="display:flex;align-items:flex-end">{"".join(lanes_up)}</div>'
    f'<div style="height:44px;background:{C["pri2"]};border-radius:10px;'
    f'display:flex;align-items:center;padding:0 8px">{"".join(bus_evts)}</div>'
    f'<div style="display:flex;justify-content:center;padding-top:10px">'
    f'<span style="font-size:10.5px;color:{C["ink3"]}">事件匯流排 · '
    f'domain 不直接互相呼叫，只發送與訂閱事實</span></div></div>', grow=True)))

# ── UCFlow D：多條 UC 疊合，找 domain 熱點 ─────────────
HEAT = {"Workspace":[1,0,0,0,1],"Schema":[1,1,0,0,1],"Corpus":[1,1,1,1,1],
        "Graph":[0,1,1,1,1],"TicketDetail":[0,0,0,1,0],
        "Layout":[0,1,1,1,0],"Diagnostics":[0,0,0,0,1]}
hrows = []
for d, vals in HEAT.items():
    tot = sum(vals)
    bars = "".join(
      f'<div style="flex:1;height:22px;border-radius:5px;'
      f'background:{C["pri"] if v else C["surf2"]}"></div>' for v in vals)
    hrows.append(
      f'<div style="display:grid;grid-template-columns:118px 1fr 78px;gap:12px;'
      f'align-items:center;height:32px">'
      f'<span style="font-size:12px;font-weight:{600 if tot>=4 else 450};'
      f'color:{C["priInk"] if tot>=4 else C["ink"]}">{d}</span>'
      f'<div style="display:flex;gap:4px">{bars}</div>'
      f'<div style="display:flex;align-items:center;gap:6px">'
      f'<div style="flex:1;height:5px;border-radius:3px;background:{C["surf3"]};'
      f'overflow:hidden"><div style="width:{tot/5*100:.0f}%;height:100%;'
      f'background:{C["pri"]}"></div></div>'
      f'<span style="font-size:10.5px;color:{C["ink3"]};width:14px">{tot}</span></div></div>')
FILES["UCFlowD.dc.html"] = shell("flow","UC Flow 視圖","方案 D · 多條 UC 疊合，找出貫穿最多流程的 domain",
  pad(card(
    f'<div style="display:grid;grid-template-columns:118px 1fr 78px;gap:12px;'
    f'padding-bottom:8px;border-bottom:1px solid {C["line2"]}">'
    f'<span style="font-size:10.5px;color:{C["ink3"]};font-weight:600">Domain</span>'
    f'<div style="display:flex;gap:4px">' +
    "".join(f'<span style="flex:1;font-size:10px;color:{C["ink3"]};text-align:center">'
            f'{u.split(" ")[0]}</span>' for u in UCS) +
    f'</div><span style="font-size:10.5px;color:{C["ink3"]};font-weight:600;'
    f'text-align:right">貫穿數</span></div>'
    f'<div style="flex:1;min-height:0;display:flex;flex-direction:column;'
    f'justify-content:center">{"".join(hrows)}</div>'
    f'<div style="padding-top:8px;border-top:1px solid {C["line2"]};font-size:11px;'
    f'color:{C["ink3"]}">Corpus 貫穿全部 5 條 flow——改動它的影響面最大</div>',
    grow=True)))
print(f"批次完成: {len(FILES)}")

# ── TicketList B：主題分組（track board --group-by topic）──
TOPICS = [
  ("schema 匯出與消費", "P1", [
    ("W3-1113","P1","上游產出 tracking_schema.json","completed"),
    ("W3-1114","P2","commit 層偵測 JSON 過期","pending"),
    ("W3-1115","P2","where.layer 值域處置評估","pending")]),
  ("doc CLI 缺陷", "P1", [
    ("W1-002","P1","doc update status 欄位誤報","pending"),
    ("W3-1117","P3","doc create --title 不寫入檔案","pending")]),
  ("hook 退場流程", "P2", [
    ("W3-1111","P2","dispatch-record-hook 加入排除清單","completed")]),
]
UNASSIGNED = [("W2-007","P2","遷移 calculations.dart 至 lib/domain","completed"),
              ("W3-740","P2","調整註冊時機或加回滾","completed")]
ST = {"completed": C["ok"], "pending": C["warn"], "in_progress": C["pri"]}

def topic_rows(items):
    return "".join(
      f'<div style="display:flex;align-items:center;gap:9px;height:29px;'
      f'padding-left:22px">'
      f'{icon(I["chev"],11,C["line"])}'
      f'<span style="font-size:11px;font-family:{MONO};color:{C["ink2"]};'
      f'width:74px;flex:none">{sid}</span>'
      f'<span style="font-size:10px;color:{C["ink3"]};width:20px;flex:none">[{p}]</span>'
      f'<span style="font-size:12px;flex:1;min-width:0;overflow:hidden;'
      f'text-overflow:ellipsis;white-space:nowrap">{t}</span>'
      f'<span style="font-size:10.5px;color:{ST[s]};font-weight:600;'
      f'flex:none">{s}</span></div>' for sid, p, t, s in items)

secs = []
for name, top, items in TOPICS:
    secs.append(
      f'<div style="display:flex;flex-direction:column;gap:2px">'
      f'<div style="display:flex;align-items:baseline;gap:8px;height:28px">'
      f'{icon(I["down"],13,C["priInk"])}'
      f'<span style="font-size:12.5px;font-weight:600;color:{C["priInk"]}">{name}</span>'
      f'<span style="font-size:11px;color:{C["ink3"]}">'
      f'({len(items)} tasks, 最高優先級={top})</span></div>'
      f'{topic_rows(items)}</div>')
secs.append(
  f'<div style="display:flex;flex-direction:column;gap:2px;margin-top:4px;'
  f'padding-top:10px;border-top:1px dashed {C["line"]}">'
  f'<div style="display:flex;align-items:baseline;gap:8px;height:28px">'
  f'{icon(I["down"],13,C["ink3"])}'
  f'<span style="font-size:12.5px;font-weight:600;color:{C["ink2"]}">未歸屬</span>'
  f'<span style="font-size:11px;color:{C["ink3"]}">({len(UNASSIGNED)} tasks)</span></div>'
  f'{topic_rows(UNASSIGNED)}</div>')

FILES["TicketListB.dc.html"] = shell("ticket","Ticket 清單",
  "主題模式 · 一次看到所有主題連同其票，供「先選主題再選票」",
  pad(card(
    f'<div style="flex:1;min-height:0;display:flex;flex-direction:column;gap:9px">'
    f'{"".join(secs)}</div>'
    f'<div style="padding-top:9px;border-top:1px solid {C["line2"]};font-size:11px;'
    f'color:{C["ink3"]};line-height:1.6">'
    f'排序：最高優先級（P0 最前）→ 票數降冪。'
    f'主題歸屬讀自 append-only 中央清單，非 frontmatter 欄位。</div>', grow=True)),
  toolbar=seg(["列表","主題"], 1))

# ── ProjectPicker C：首次使用極簡 ─────────────────────
FILES["ProjectPickerC.dc.html"] = shell("folder","選擇專案","方案 C · 單一動作優先，最近清單退居次要",
  f'<div style="height:100%;display:flex;flex-direction:column;align-items:center;'
  f'justify-content:center;gap:26px;padding:40px;box-sizing:border-box">'
  f'<div style="width:76px;height:76px;border-radius:20px;background:{C["pri2"]};'
  f'display:flex;align-items:center;justify-content:center">'
  f'{icon(I["folder"],34,C["priInk"])}</div>'
  f'<div style="display:flex;flex-direction:column;align-items:center;gap:8px;'
  f'max-width:430px;text-align:center">'
  f'<span style="font-size:19px;font-weight:600">選擇工作資料夾</span>'
  f'<span style="font-size:12.5px;color:{C["ink2"]};line-height:1.75">'
  f'App 將在其中讀取 <code style="font-family:{MONO};background:{C["surf2"]};'
  f'padding:1px 5px;border-radius:4px">docs/</code> 下的圖譜節點與 ticket。'
  f'此授權會被記住，下次開啟不需重選。</span></div>'
  f'<div style="display:flex;gap:10px">{btn("選擇資料夾…", True)}</div>'
  f'<div style="display:flex;flex-direction:column;align-items:center;gap:7px;'
  f'padding-top:16px;border-top:1px solid {C["line2"]};width:420px">'
  f'<span style="font-size:10.5px;color:{C["ink3"]};font-weight:600">最近開啟</span>'
  f'<div style="display:flex;gap:16px">' +
  "".join(f'<span style="font-size:11.5px;color:{C["pri"]}">{n}</span>'
          for n,_,_,_,_,_ in PROJS[:3]) +
  f'</div></div></div>')

# ── ProjectPicker D：側欄常駐切換器（不是獨立畫面）──────
sw_items = "".join(
  f'<div style="display:flex;align-items:center;gap:9px;padding:8px 10px;'
  f'border-radius:7px;background:{C["pri2"] if i==0 else "transparent"}">'
  f'{icon(I["folder"],15,C["priInk"] if i==0 else C["ink3"])}'
  f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:1px">'
  f'<span style="font-size:12px;font-weight:{600 if i==0 else 450};'
  f'color:{C["priInk"] if i==0 else C["ink"]}">{n}</span>'
  f'<span style="font-size:10px;color:{C["ink3"]}">{nd} 節點 · {tk} 票</span></div>'
  f'{chip(str(gp), C["errBg"], C["err"]) if gp else ""}</div>'
  for i,(n,p,nd,tk,gp,t) in enumerate(PROJS))
ghost2 = "".join(
  f'<div style="display:grid;grid-template-columns:120px repeat(4,1fr);gap:8px;'
  f'height:30px;align-items:center;opacity:.4">'
  f'<span style="font-size:11.5px">{d}</span>' +
  "".join('<div style="text-align:center;font-size:14px;color:%s">%s</div>'
          % (C["pri"] if (i+j) % 3 else C["line"], "●" if (i+j) % 3 else "·")
          for j in range(4)) + '</div>' for i, d in enumerate(DOMAINS[:6]))
FILES["ProjectPickerD.dc.html"] = shell("grid","Domain 視圖",
  "方案 D · 專案切換收進側欄浮層，不佔獨立畫面",
  f'<div style="height:100%;position:relative;padding:20px;box-sizing:border-box">'
  f'{card(ghost2, grow=True)}'
  f'<div style="position:absolute;left:12px;top:2px;width:262px;'
  f'background:{C["surface"]};border:1px solid {C["line"]};border-radius:11px;'
  f'box-shadow:0 10px 30px rgba(0,0,0,.14);padding:8px;display:flex;'
  f'flex-direction:column;gap:2px">'
  f'<div style="font-size:10.5px;color:{C["ink3"]};font-weight:600;padding:4px 10px 6px">'
  f'切換專案</div>{sw_items}'
  f'<div style="height:1px;background:{C["line2"]};margin:5px 8px"></div>'
  f'<div style="display:flex;align-items:center;gap:9px;padding:8px 10px">'
  f'{icon(I["folder"],15,C["pri"])}'
  f'<span style="font-size:12px;color:{C["pri"]};font-weight:550">'
  f'選擇其他資料夾…</span></div></div></div>')

# ── 移除未選中的方案 ─────────────────────────────────
for drop in ("GapReportB.dc.html","NodeDetailA.dc.html","TraceB.dc.html",
             "ProjectPickerA.dc.html","ProjectPickerB.dc.html","ProjectPickerC.dc.html",
             "UCFlowA.dc.html","UCFlowC.dc.html","UCFlowD.dc.html"):
    FILES.pop(drop, None)
    p = Path(drop)
    if p.exists(): p.unlink()

# ── 寫出 ─────────────────────────────────────────────
import json
for name, src in FILES.items():
    Path(name).write_text(src, encoding='utf-8')
ROWS = [("Domain 視圖 · 矩陣與泳道雙模式", ["Main.dc.html","DomainSwimlane.dc.html"]),
        ("Ticket 清單 · 列表與主題雙模式", ["TicketListA.dc.html","TicketListB.dc.html"]),
        ("UC Flow 視圖 · 追溯視圖", ["UCFlowB.dc.html","TraceA.dc.html"]),
        ("破洞報告 · 節點詳情", ["GapReportA.dc.html","NodeDetailB.dc.html"]),
        ("專案切換 · 側欄浮層，非獨立畫面", ["ProjectPickerD.dc.html"])]
arts, notes = [], []
for r,(label, files) in enumerate(ROWS):
    y = r * 980
    for c, f in enumerate(files):
        arts.append({"file": f, "x": c * 1400, "y": y, "w": W, "h": H})
    notes.append({"id": f"row-{r+1}", "x": -340, "y": y + 40, "w": 290, "text": label})
Path("canvas.json").write_text(json.dumps(
    {"artboards": arts, "annotations": notes, "launch": {"view": "canvas"}},
    ensure_ascii=False, indent=2), encoding='utf-8')
print(f"✅ {len(FILES)} 個 artboard")
