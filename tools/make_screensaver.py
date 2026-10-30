# Ecran de repaus Meteo Alarm Kindle: python3 make_screensaver.py CAPTURA.png IESIRE.png
# CAPTURA = ecranul aplicației (portret 758x1024 sau peisaj 1024x758); IESIRE = PNG gri 758x1024.
from PIL import Image, ImageDraw, ImageFont
import sys
W,H=758,1024
F="/usr/share/fonts/truetype/liberation/LiberationSans-"
def f(s,b=False): return ImageFont.truetype(F+("Bold" if b else "Regular")+".ttf",s)
im=Image.new("L",(W,H),255); d=ImageDraw.Draw(im)
def ctext(y,t,fo,fill=0):
    w=d.textlength(t,font=fo); d.text(((W-w)/2,y),t,font=fo,fill=fill)
ctext(36,"Meteo Alarm Kindle",f(58,True))
ctext(108,"Ceas, vreme și avertizări MeteoAlarm",f(28))
ctext(144,"pentru Kindle Paperwhite",f(28))
# The app's screen in a device frame (landscape captures get a landscape frame).
src=Image.open(sys.argv[1]).convert("L")
sw,sh=src.size
s=0.52 if sw>sh else 0.43
tw,th=int(sw*s),int(sh*s)
th_img=src.resize((tw,th),Image.LANCZOS)
fx,fy=(W-tw)//2,212
pad=22
if sw>sh:
    d.rounded_rectangle((fx-pad-18,fy-pad,fx+tw+pad,fy+th+pad),radius=28,fill=0x33)
else:
    d.rounded_rectangle((fx-pad,fy-pad,fx+tw+pad,fy+th+pad+18),radius=28,fill=0x33)
d.rectangle((fx-2,fy-2,fx+tw+1,fy+th+1),fill=0x99)
im.paste(th_img,(fx,fy))
y=fy+th+pad+(0 if sw>sh else 18)+30
lines=["Ora și data, mari, vizibile de departe",
       "Vremea acum și pe 5 zile (Open-Meteo)",
       "Coduri galben, portocaliu și roșu",
       "UV, umiditate, Lună, presiune, calitatea aerului",
       "315 localități din România"]
fo=f(26)
for t in lines:
    fs=26
    while d.textlength(t,font=f(fs))>W-80: fs-=1
    fo=f(fs)
    w=d.textlength(t,font=fo); x=(W-w)/2
    d.ellipse((x-24,y+9,x-12,y+21),fill=0x55)
    d.text((x,y),t,font=fo,fill=0); y+=38
ctext(y+8,"github.com/viorelrb-alt/meteo-alarm-kindle-ro",f(22),0x55)
# bottom band
by=H-118
d.rectangle((0,by,W,H),fill=0xDD)
d.line((0,by,W,by),fill=0,width=2)
ctext(by+20,"Kindle-ul este în repaus.",f(30,True))
ctext(by+62,"Apasă scurt butonul de pornire, de pe marginea de jos.",f(23))
im.save(sys.argv[2],optimize=True)
