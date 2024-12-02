FROM python:3.13.0

WORKDIR /app

COPY ./scripts ./app/scripts

RUN python3 -m venv /app/brix

RUN /app/brix/bin/pip install gama-client==1.2.0
RUN /app/brix/bin/pip install websockets==13.1
RUN /app/brix/bin/pip install nest-asyncio==1.6.0

CMD ["/app/brix/bin/python", "/app/scripts/brix.py"]
