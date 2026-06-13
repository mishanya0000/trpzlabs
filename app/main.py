import os
import sys
from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse

app = FastAPI(title="mywebapp")

NOTES = [
    {"id": 1, "title": "Перша нотатка", "content": "Це вміст першої нотатки", "created_at": "2026-06-12 12:00:00"},
    {"id": 2, "title": "Друга нотатка", "content": "Це вміст другої нотатки", "created_at": "2026-06-12 12:05:00"}
]

def render_html_table(data, fields):
    html = "<table border='1'>"
    html += "<tr>" + "".join(f"<th>{f}</th>" for f in fields) + "</tr>"
    for row in data:
        html += "<tr>" + "".join(f"<td>{row.get(f)}</td>" for f in fields) + "</tr>"
    html += "</table>"
    return html

@app.get("/", response_class=HTMLResponse)
async def root():
    return """
    <h1>mywebapp API Endpoints</h1>
    <ul>
        <li><a href="/notes">GET /notes</a> - Список усіх нотаток</li>
    </ul>
    """

@app.get("/health/alive")
async def alive():
    return Response(content="OK", status_code=200)

@app.get("/health/ready")
async def ready():
    return Response(content="OK", status_code=200)

@app.get("/notes")
async def get_notes(request: Request):
    accept = request.headers.get("accept", "")
    if "text/html" in accept:
        html_content = f"<h1>Notes List</h1>{render_html_table(NOTES, ['id', 'title'])}"
        return HTMLResponse(content=html_content)
    return JSONResponse(content=[{"id": n["id"], "title": n["title"]} for n in NOTES])

@app.post("/notes")
async def create_note(request: Request):
    try:
        body = await request.json()
    except:
        body = {"title": "Нова нотатка", "content": "Вміст"}
    new_id = len(NOTES) + 1
    new_note = {
        "id": new_id,
        "title": body.get("title", f"Note {new_id}"),
        "content": body.get("content", "Empty content"),
        "created_at": "2026-06-12 14:00:00"
    }
    NOTES.append(new_note)
    return JSONResponse(content=new_note, status_code=201)

@app.get("/notes/{note_id}")
async def get_note(note_id: int, request: Request):
    note = next((n for n in NOTES if n["id"] == note_id), None)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    accept = request.headers.get("accept", "")
    if "text/html" in accept:
        html_content = f"<h1>Note Details</h1>{render_html_table([note], ['id', 'title', 'content', 'created_at'])}"
        return HTMLResponse(content=html_content)
    return JSONResponse(content=note)
