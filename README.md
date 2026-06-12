# My Web Application (FastAPI + Nginx + Systemd Sockets)

Проєкт автоматизованого розгортання веб-додатка на FastAPI в ОС Ubuntu з використанням Systemd Sockets та Nginx як Reverse Proxy.

## Особливості архітектури:
- **Ізоляція:** Запуск у віртуальному середовищі `venv` від імені безпечного системного користувача `app`.
- **Продуктивність:** Взаємодія між Nginx та Uvicorn реалізована через швидкі **Unix Domain Sockets** за допомогою Systemd сокет-активації (`--fd 3`).
- **Автоматизація:** Демонізація через Systemd сервіс з автоматичним перезапуском та автоматичним накатом міграцій БД.

## Локальний запуск (Development)
1. `python3 -m venv venv`
2. `source venv/bin/activate`
3. `pip install -r requirements.txt`
4. `python migrate.py`
5. `uvicorn app.main:app --reload`
