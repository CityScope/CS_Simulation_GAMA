import asyncio
import copy
import json
import os
from threading import Lock, Thread
from time import sleep
from typing import Dict

import rel
import websocket
import websockets
from gama_client.sync_client import GamaSyncClient

class MicroBrix():

    remote_host='cityio.media.mit.edu/cityio'
    geogrid_data={}
    geogrid={}

    def __init__(self, table_name=None,
            quietly=False,
            host_mode='remote',
            host_name=None,
            core=False,
            core_name=None,
            core_description=None,
            core_category=None,
            keep_updating=False,
            update_interval=0.1,
            module_function=None,
            save=False
    ):

        self.data_from_websocket=[
            {
                "type": "bar",
                "data": {
                    "walking": {
                        "value": 0.25,
                        "description": "An example 1"
                    },
                    "bike": {
                        "value": 0.5,
                        "description": "An example 2"
                    },
                    "car": {
                        "value": 0.75,
                        "description": "An example 3"
                    },
                    "bus": {
                        "value": 1.0,
                        "description": "An example 4"
                    }
                },
                "properties": {

                }
            },
            {
                "type": "radar",
                "data": {
                    "walking": {
                        "value": 1.0,
                        "description": "An example 1"
                    },
                    "bike": {
                        "value": 0.75,
                        "description": "An example 2"
                    },
                    "car": {
                        "value": 0.5,
                        "description": "An example 3"
                    },
                    "bus": {
                        "value": 0.25,
                        "description": "An example 4"
                    }
                },
                "properties": {

                }
            }
        ]
        self.previous_data_from_websocket=[]
        self.data_lock=Lock()

        if host_name is None:
            self.host=self.remote_host
        else:
            self.host=host_name.strip('/')
        self.host='127.0.0.1:8080' if host_mode=='local' else self.host

        self.quietly=quietly
        self.save=save
        self.keep_updating=keep_updating
        self.update_interval=update_interval
        self.table_name=table_name
        self.core=core
        self.core_name=core_name
        self.core_description=core_description
        self.core_category=core_category
        self.secure_protocol='' if host_mode=='local' else 's'
        self.front_end_url=f'http{self.secure_protocol}://cityio-beta.media.mit.edu/?cityscope={self.table_name}'
        self.cityIO_post_url=f'http{self.secure_protocol}://{self.host}/api/table/{table_name}/'
        self.cityIO_list=f'http{self.secure_protocol}://{self.host}/api/table/list/'
        self.cityIO_wss=f'ws{self.secure_protocol}://{self.host}/module'

        if core:
            self.cityIO_wss=self.cityIO_wss + '/core'

        if(module_function==None):
            raise ValueError("module_function should contain a function that returns DeckGL layers")

        self.module_function=module_function

        if(not self.quietly):
            websocket.enableTrace(True)

        self.ws=websocket.WebSocketApp(self.cityIO_wss,
            on_open=self.on_open,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close)

    def on_message(self, ws, message):
        dict_rec=json.loads(message)
        message_type=dict_rec['type']
        if(message_type=='TABLE_SNAPSHOT'):
            table_name=dict_rec['content']['tableName']
            self.geogrid_data[table_name]=dict_rec['content']['snapshot']['GEOGRIDDATA']
            self.geogrid[table_name]=dict_rec['content']['snapshot']['GEOGRID']
            self.perform_update(table_name)
            thread=Thread(target=self.threaded_function, args=(table_name, ), daemon=True)
            thread.start()
        elif(message_type=='GEOGRIDDATA_UPDATE'):
            print(dict_rec)
            table_name=dict_rec['content']['tableName']
            self.geogrid_data[table_name]=dict_rec['content']['geogriddata']
            self.perform_update(table_name)
        elif(self.core and message_type=='SUBSCRIPTION_REQUEST'):
            requester=dict_rec['content']['table']
            self.send_message(json.dumps({"type":"SUBSCRIBE","content":{"gridId":requester}}))
        elif(self.core and message_type=='SUBSCRIPTION_REMOVAL_REQUEST'):
            requester=dict_rec['content']['table']
            # self._clear_values(requester)
            self.send_message(json.dumps({"type":"UNSUBSCRIBE","content":{"gridId":requester}}))

    def on_error(self, ws, error):
        print(error)

    def on_close(self, ws, close_status_code, close_msg):
        print("## Connection closed")

    def on_open(self, ws):
        print("## Opened connection")
        if self.core:
            self.send_message(json.dumps({"type":"CORE_MODULE_REGISTRATION","content":{"name":self.core_name, "description": self.core_description, "moduleType":self.core_category}}))
        else:
            self.send_message(json.dumps({"type":"SUBSCRIBE","content":{"gridId":self.table_name}}))

    def send_message(self, message):
        self.ws.send(message)

    def threaded_function(self, table_name):
        if(self.keep_updating):
            while True:
                try:
                    sleep(self.update_interval)
                    self.perform_update(table_name)
                except:
                    continue

    def _send_indicators(self, layers, numeric, table):
        if(layers is not None and numeric is not None):
            message={"type": "MODULE", "content":{"gridId": table, "save": self.save, "moduleData":{"layers":layers,"numeric":numeric}}}
        elif(layers is not None):
            message={"type": "MODULE", "content":{"gridId": table, "save": self.save, "moduleData":{"layers":layers}}}
        elif(numeric is not None):
            message={"type": "MODULE", "content":{"gridId": table, "save": self.save, "moduleData":{"numeric":numeric}}}

        self.send_message(json.dumps(message))

    def perform_update(self, table):
        layers, numeric=self.module_function(self.geogrid[table],self.geogrid_data[table])

        with self.data_lock:
            if self.data_from_websocket != self.previous_data_from_websocket:
                self._send_indicators(layers, numeric, table)
                self.previous_data_from_websocket=copy.deepcopy(self.data_from_websocket)

    def get_received_data(self):
        with self.data_lock:
            return self.data_from_websocket

    def listen(self):
        self.ws.run_forever(dispatcher=rel, reconnect=5)
        rel.signal(2, rel.abort)  # Keyboard Interrupt
        rel.dispatch()

    def stop(self):
        self.ws.close()

async def handle_connection(websocket, path, connection):
    # print("Connected client")
    try:
        async for message in websocket:
            data=json.loads(message)

            with connection.data_lock:
                if connection.data_from_websocket != data:
                    connection.data_from_websocket=data

            response={"status": "received", "data": data}
            await websocket.send(json.dumps(response))
    except websockets.ConnectionClosed:
        print("Client disconnected")
    except Exception as e:
        print(f"Error: {e}")

async def start_server(connection):
    server=await websockets.serve(lambda ws, path: handle_connection(ws, path, connection), "localhost", 8000, max_size=None)
    # print("Additional WebSocket server started at ws://localhost:8000")
    await server.wait_closed()

def start_websocket_server(connection):
    asyncio.run(start_server(connection))

def indicator(geogrid, geogrid_data):
    r=connection.get_received_data()
    layers=[]
    numeric=[]

    for item in r:
        if item["type"]=="bar":
            for mean in item["data"]:
                numeric.append({"viz_type": "bar", "name": mean, "value": item["data"][mean]["value"], "description": item["data"][mean]["description"]})
        elif item["type"]=="radar":
            for mean in item["data"]:
                numeric.append({"viz_type": "radar", "name": mean, "value": item["data"][mean]["value"], "description": item["data"][mean]["description"]})
        else:
            layers.append(item)

    return layers, numeric

async def async_command_answer_handler(message: Dict):
    print("Here is the answer to an async command: ", message)


async def gama_server_message_handler(message: Dict):
    print("Here is the message from Gama-server:", message)

async def gama_client():
    client = GamaSyncClient("localhost", 6868, async_command_answer_handler, gama_server_message_handler)
    await client.connect(False)
    command_answer = client.sync_load("C:/Users/carlo/CS_Simulation_GAMA/CS_CityScope_GAMA/models/GameIT/gameit_cityscope.gaml", "gameit")

    if "type" in command_answer.keys() and command_answer["type"] == "CommandExecutedSuccessfully":
        await client.play(exp_id=command_answer["content"])

    while True:
        await asyncio.sleep(1)

def start_gama_client():
    asyncio.run(gama_client())

if __name__=="__main__":
    connection=MicroBrix(table_name='volpe-habm', module_function=indicator, keep_updating=True, quietly=True)

    ws_server_thread=Thread(target=start_websocket_server, args=(connection,), daemon=True)
    ws_server_thread.start()

    ws_gama_client=Thread(target=start_gama_client, daemon=True)
    ws_gama_client.start()

    connection.listen()
    connection.stop()
