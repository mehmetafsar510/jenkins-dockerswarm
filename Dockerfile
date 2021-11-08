FROM python:alpine
COPY ./app /app
WORKDIR /app
RUN pip install -r requirements.txt
EXPOSE 8000
CMD python ./phonebook-app.py