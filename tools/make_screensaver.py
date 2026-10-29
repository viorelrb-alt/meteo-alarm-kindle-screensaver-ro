from PIL import Image, ImageDraw, ImageFont, ImageFilter
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
# screen thumbnail in a device frame
src=Image.open(sys.argv[1]).convert("L")
s=0.43; tw,th=int(758*s),int(1024*s)
th_img=src.resize((tw,th),Image.LANCZOS)
fx,fy=(W-tw)//2,198
pad=22
d.rounded_rectangle((fx-pad,fy-pad,fx+tw+pad,fy+th+pad+18),radius=28,fill=0x33)
d.rectangle((fx-2,fy-2,fx+tw+1,fy+th+1),fill=0x99)
im.paste(th_img,(fx,fy))
y=fy+th+pad+18+34
lines=["Ora și data, mari, vizibile de departe",
       "Vremea acum și pe 5 zile (Open-Meteo)",
       "Coduri galben, portocaliu și roșu",
       "320 de localități din România"]
fo=f(26)
for t in lines:
    w=d.textlength(t,font=fo); x=(W-w)/2
    d.ellipse((x-24,y+9,x-12,y+21),fill=0x55)
    d.text((x,y),t,font=fo,fill=0); y+=38
ctext(y+10,"github.com/viorelrb-alt/kindle-weather-clock-ro",f(22),0x55)
# bottom band
by=H-118
d.rectangle((0,by,W,H),fill=0xDD)
d.line((0,by,W,by),fill=0,width=2)
ctext(by+20,"Kindle-ul este în repaus.",f(30,True))
ctext(by+62,"Apasă scurt butonul de pornire, de pe marginea de jos.",f(23))
im.save(sys.argv[2],optimize=True)
