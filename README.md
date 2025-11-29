# 🎁 Secret Santa App  
Fullstack application for organizing Secret Santa events.  
Built with **Flutter (frontend)** and **Python FastAPI (backend)**.

---

## 📌 Overview  
Secret Santa App allows users to add participants and automatically generate random gift pairings.  
Pairs are stored on the backend and synchronized in real-time with all connected clients.

This project was created to practice:  
- Flutter UI & state management  
- REST API communication  
- WebSockets  
- Backend development (FastAPI + SQLite)  
- Fullstack integration

---

## ✨ Features  

### ✔ Frontend (Flutter)
- Add and remove users  
- Real-time updates using WebSocket  
- Display generated Secret Santa pairs  
- Error, empty and loading states  
- Local state management  
- Integration with backend API

### ✔ Backend (FastAPI)
- Full REST API for user management  
- Random pair generation  
- SQLite database for storing results  
- WebSocket broadcasting  
- CORS support  
- Structured endpoints

---

## 🛠 Tech Stack  

### **Frontend**
- Flutter  
- Dart  
- HTTP (REST API)  
- WebSockets  
- Provider (basic state management)

### **Backend**
- FastAPI  
- Python  
- SQLite  
- Uvicorn  
- WebSockets  

---

## 📂 Project Structure  
``SecretSantaAPP/
├─ secretsantafront/ # Flutter frontend source code
├─ backend/ # FastAPI backend
├─ users.db # SQLite database
└─ README.md``

---

## 🚀 Running the Project  

## ** 1. Run the backend **
cd backend
pip install -r requirements.txt
uvicorn main:app --reload

Backend will be available at:
http://127.0.0.1:8000

## ** 2. Run the frontend **
``cd secretsantafront
flutter pub get
flutter run``
For Flutter Web:
``flutter run -d chrome``


## 🔌 API Endpoints

### **Users**
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET    | `/users` | Get all users |
| GET    | `/users/{id}` | Get user by ID |
| POST   | `/users` | Add new user |
| DELETE | `/users/remove/{id}` | Remove user |

---

### **Results**
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST   | `/results` | Save generated pairings |
| GET    | `/results` | Get saved results |
| DELETE | `/results/clear` | Clear all results |

---

### **WebSocket**
`/auto_update`
Used for real-time updates for all connected clients.



## 🧩 Known Issues / Areas for Improvement
Hard-coded API URL in Flutter (should be replaced with config)
Inconsistent backend response formats (needs unification)
Missing validation on input fields
No unit tests (frontend & backend)
Error handling could be improved
Add Docker support (backend + frontend)
Clean architecture separation in Flutter can be improved

### DarkMode / LightMode
<img width="735" height="703" alt="UsersPage" src="https://github.com/user-attachments/assets/48798439-2941-4587-ab2e-a0b525c17265" />
<img width="730" height="698" alt="MenuView" src="https://github.com/user-attachments/assets/45aa4847-6b00-4638-8798-558eb407832e" />
<img width="733" height="701" alt="PassThePhoneMode" src="https://github.com/user-attachments/assets/63c13302-90db-4b5b-b27f-fe28444918d4" />
<img width="728" height="700" alt="AllPairingsView" src="https://github.com/user-attachments/assets/72754bb2-e1b3-4c1c-a1a3-48e7cad3a45c" />

<img width="734" height="702" alt="UsersPageLight" src="https://github.com/user-attachments/assets/5dcbcd75-af20-4918-8cb7-38df104bd95b" />
<img width="729" height="696" alt="MenuViewLight" src="https://github.com/user-attachments/assets/ad36abdd-eb4e-496c-a5aa-689551574803" />
<img width="735" height="702" alt="AllPairingsView" src="https://github.com/user-attachments/assets/50f3d24c-f7d6-4d68-a7d5-7cbde1d32da2" />
<img width="728" height="702" alt="PassThePhoneLIght" src="https://github.com/user-attachments/assets/8f3b11b6-3688-4e78-9a5d-5bef04fbbb86" />





