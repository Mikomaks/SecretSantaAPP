from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv
import sqlite3
from pydantic import BaseModel,EmailStr,Field
import random
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse
from starlette.staticfiles import StaticFiles
from starlette.websockets import WebSocket, WebSocketDisconnect

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def init_db():

    with sqlite3.connect("users.db") as conn:
        cur = conn.cursor()
        cur.executescript("""

    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
    );

    CREATE TABLE IF NOT EXISTS results (
        sender_id INTEGER NOT NULL,
    receiver_id INTEGER NOT NULL,
    PRIMARY KEY (sender_id),
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE
    );
    
    DELETE FROM results;
    """)
        conn.commit()

init_db()
slowniczek = {}

#userinput
class UserInput(BaseModel):
    name: str = Field(...,min_length=1)
    email: EmailStr


def add_user_to_db(name : str, email : str) -> int:
    with sqlite3.connect("users.db") as conn:
        name = name.capitalize()
        cur = conn.cursor()
        cur.execute("INSERT INTO users (name,email) VALUES (?,?)",(name,email))
        conn.commit()
        return cur.lastrowid

@app.post("/users/add",status_code=201)
async def post_user(user : UserInput):
    try:
        new_id = add_user_to_db(user.name,user.email)
        await call_users()
        return {f"id:{new_id} user successfully added"}

    except sqlite3.IntegrityError:
        raise HTTPException(status_code=400,detail="Email is already in database!")


@app.get("/users_simple",status_code=200)
async def get_users_simple():
    with sqlite3.connect("users.db") as conn:
        dictionary = {}
        cur = conn.cursor()
        cur.execute("SELECT * FROM users")
        rows = cur.fetchall()
        for row in rows:
            dictionary[row[0]] = row[2]
            #ID -> email
        return dictionary

@app.get("/users",status_code=200)
async def get_users():
    with sqlite3.connect("users.db") as conn:
        users = []
        conn.row_factory = sqlite3.Row # to zeby moc uzywc row[nazwa]
        cur = conn.cursor()
        cur.execute("SELECT * FROM users")
        rows = cur.fetchall()
        for row in rows:
            users.append({
                "id":row["id"],
                "name":row["name"],
                "email":row["email"]
            })
        return users

@app.post("/run_drawing",status_code=200)
async def run_drawing():
    try:
        slowniczek = await get_users_simple()
        ##print(len(slowniczek))

        #error handing
        if len(slowniczek)  <= 1:
            raise HTTPException(status_code=409,detail="Not enough users in databse to make the draws!")
        else:
            draw_response = run_draw(slowniczek)
            return draw_response
    except Exception as e:
        raise HTTPException(status_code=400,detail=f"There was a problem with getting the users {e}")


def save_results(drawings : dict):
    try:
        with sqlite3.connect("users.db") as conn:
            cur = conn.cursor()
            cur.execute("DELETE FROM results")
            for giv,rec in drawings.items():
                cur.execute("INSERT INTO results VALUES (?,?)",(giv,rec))

            conn.commit()
        return True #if success
    except Exception as ex:
        print(ex)
        return False


#this function makes the drawing and then posts the results into DB
def run_draw(slowniczek : dict) -> dict:
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
    for x,y in gifter.items():
        print(x,"->" ,y)


    if save_results(gifter):
        print("Drawings saved")
    else:
        print("Drawings not saved!")

    return gifter

@app.get("/results",status_code=200)
async def get_results():
    with sqlite3.connect("users.db") as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM results")
        rows = cur.fetchall()
        results_dict = {}   #GIVER : RECEIVER!!
        for row in rows:
            results_dict[row[0]] = row[1]

        if len(results_dict) <= 1:
            return "There are no drawings!"
        else:
            return results_dict

@app.get("/users/{id}",status_code=200)
async def get_user(id: int):
    with sqlite3.connect("users.db") as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM users WHERE id = ?",(id,))
        row = cur.fetchone()
        if row is None:
            raise HTTPException(status_code=404,detail="User not found!")
        else:
            return row


@app.delete("/users/remove/{user_id}",status_code=200)
async def delete_user(user_id: int):
    with sqlite3.connect("users.db") as conn:
            cur = conn.cursor()
            cur.execute("SELECT id FROM users WHERE id = ?",(user_id,))
            row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=404,detail=f"User {user_id} not found!")
            else:
                cur.execute("DELETE FROM users WHERE id = ?",(user_id,))
                conn.commit()
                await call_users()
                return JSONResponse(status_code=200,content={"message":f"User {row} deleted successfully!"})

app_users: list[WebSocket] = []

@app.websocket("/ws")
async def websocket(ws : WebSocket):
    await ws.accept()
    app_users.append(ws)
    print(app_users)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        app_users.remove(ws)

async def call_users():
    for ws in app_users.copy():
        await ws.send_text("E uwaga aktualizować się proszę!")
        print("INFORMING ALL USERS!")

app.mount(
    "/"
    , StaticFiles(directory="/Users/mikomaks/Desktop/Programowanie/Projekty/SecretSanta APP/secretsantafront/build/web", html=True), name="frontend")
