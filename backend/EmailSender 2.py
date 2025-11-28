import os
import smtplib
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from dotenv import load_dotenv
import random

load_dotenv()

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587

##CHANGE TO YOUR SMTP USER
SMTP_USER = os.getenv("SMTP_USER")

##CHANGE TO YOUR PASSWORD (u may need to use app password if using gmail)
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")


slowniczek = {}

with open("emails", "r") as plik:
    for line in plik:
        mailname = line.split()
        if len(mailname) == 2:
            slowniczek[mailname[1]] = mailname[0]

lista = list(slowniczek.keys())
random.shuffle(lista)
gifter = {}
receivers = list(lista)
for giver in lista:
    i = random.randint(0, len(receivers)-1)
    receiver = receivers[i]
    while receiver == giver:
        i = random.randint(0, len(receivers)-1)
        receiver = receivers[i]

        #cant give present to self
        if len(receivers) == 1:
            copier = list(gifter.keys())[-1]
            temp = gifter[copier]
            gifter[copier] = receiver
            receiver = temp

    gifter[giver] = receiver
    receivers.remove(receiver)

#printer (uncomment if u wish to know the gifters and receivers)
# for x,y in gifter.items():
#     print(x,"->" ,y)


for giver,getter in gifter.items():
    email = slowniczek[giver]

    msg = MIMEMultipart()
    msg['From'] = os.getenv("SMTP_USER")
    msg['To'] = email
    msg['Subject'] = "Superaśne Mikołajki!!!"
    #gender handler
    if giver.endswith("a"):
        htmlcode = f"""<!DOCTYPE html>
                    <html>
                    <body><h1>Gratulacje wylosowałaś: {getter}</h1>
                    </body>
                    </html>"""
    else:
        htmlcode = f"""<!DOCTYPE html>
                    <html>
                    <body><h1>Gratulacje wylosowałeś: {getter}</h1>
                    </body>
                    </html>"""

    msg.attach(MIMEText(htmlcode, "html", "utf-8"))

    with open("obrazek.png","rb") as img:
        msg.attach(MIMEApplication(img.read(),Name="obrazek.png"))


    with smtplib.SMTP(SMTP_SERVER,SMTP_PORT) as server:
        server.starttls()
        server.login(SMTP_USER,SMTP_PASSWORD)
        server.sendmail(msg["From"],msg["To"],msg.as_string())
        print(f"Mail wysłany gitaśnie do {email}")



plik.close()