FROM python:3.13.0-alpine

RUN python -m venv /brix
RUN /brix/bin/python -m pip install --upgrade pip

RUN /brix/bin/pip install gama-client==1.2.0
RUN /brix/bin/pip install websockets==13.1
RUN /brix/bin/pip install nest-asyncio==1.6.0
