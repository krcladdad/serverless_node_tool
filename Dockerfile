FROM python:3.11

WORKDIR /app

COPY . /app

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 5000

CMD ["python", "app.py"]

# Alternative command to run the application
# CMD ["flask", "--app", "app", "run", "--debug", "--host=0.0.0.0"]

