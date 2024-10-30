import asyncio
import json
import os
from threading import Thread
from typing import Dict

import rel
import websocket
from websockets.asyncio import server
from websockets.exceptions import ConnectionClosed

from gama_client.message_types import MessageTypes
from gama_client.sync_client import GamaSyncClient

class Brix():

    remote_host='cityio.media.mit.edu/cityio'
    geogrid_data={}
    geogrid={}

    def __init__(self,
        table_name=None,
        quietly=False,
        host_mode='remote',
        host_name=None,
        core=False,
        core_name=None,
        core_description=None,
        core_category=None,
        save=False
    ):

        self.host='127.0.0.1:8080' if host_mode=='local' else (host_name.strip('/') if host_name else self.remote_host)
        self.secure_protocol='' if host_mode=='local' else 's'

        base_url=f'http{self.secure_protocol}://{self.host}'
        self.front_end_url=f'{base_url}/?cityscope={table_name}'
        self.cityIO_post_url=f'{base_url}/api/table/{table_name}/'
        self.cityIO_list=f'{base_url}/api/table/list/'
        self.cityIO_wss=f'ws{self.secure_protocol}://{self.host}/module{"core" if core else ""}'

        self.quietly=quietly
        self.save=save
        self.table_name=table_name
        self.core=core
        self.core_name=core_name
        self.core_description=core_description
        self.core_category=core_category

        self.ws_server_thread=Thread(target=self.start_websocket_server,daemon=True)
        self.ws_gama_client=Thread(target=self.start_gama_client,daemon=True)

        if not self.quietly:
            websocket.enableTrace(True)

        self.ws=websocket.WebSocketApp(self.cityIO_wss,
            on_open=self.on_open,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close
        )

    def on_message(self,ws,message):
        dict_rec=json.loads(message)
        message_type=dict_rec['type']

        if(message_type=='TABLE_SNAPSHOT'):
            table_name=dict_rec['content']['tableName']
            self.geogrid_data[table_name]=dict_rec['content']['snapshot']['GEOGRIDDATA']
            self.geogrid[table_name]=dict_rec['content']['snapshot']['GEOGRID']
            self.ws_server_thread.start()
            self.ws_gama_client.start()

        elif(message_type=='GEOGRIDDATA_UPDATE'):
            table_name=dict_rec['content']['tableName']
            self.geogrid_data[table_name]=dict_rec['content']['geogriddata']

        elif(self.core and message_type=='SUBSCRIPTION_REQUEST'):
            requester=dict_rec['content']['table']
            self.send_message(json.dumps({"type":"SUBSCRIBE","content":{"gridId":requester}}))

        elif(self.core and message_type=='SUBSCRIPTION_REMOVAL_REQUEST'):
            requester=dict_rec['content']['table']
            self.send_message(json.dumps({"type":"UNSUBSCRIBE","content":{"gridId":requester}}))

    def on_error(self,ws,error):
        print(error)

    def on_close(self,ws,close_status_code,close_msg):
        print("## Connection closed")

    def on_open(self,ws):
        print("## Opened connection")
        if self.core:
            self.send_message(json.dumps({"type":"CORE_MODULE_REGISTRATION","content":{"name":self.core_name,"description":self.core_description,"moduleType":self.core_category}}))
        else:
            self.send_message(json.dumps({"type":"SUBSCRIBE","content":{"gridId":self.table_name}}))

    def send_message(self,message):
        self.ws.send(message)

    def _send_indicators(self,layers,numeric):
        if(layers is not None and numeric is not None):
            message={"type":"MODULE","content":{"gridId":self.table_name,"save":self.save,"moduleData":{"layers":layers,"numeric":numeric}}}

        elif(layers is not None):
            message={"type":"MODULE","content":{"gridId":self.table_name,"save":self.save,"moduleData":{"layers":layers}}}

        elif(numeric is not None):
            message={"type":"MODULE","content":{"gridId":self.table_name,"save":self.save,"moduleData":{"numeric":numeric}}}

        self.send_message(json.dumps(message))

    def listen(self):
        self.ws.run_forever(dispatcher=rel,reconnect=5)
        rel.signal(2,rel.abort)  # Keyboard Interrupt
        rel.dispatch()

    def stop(self):
        self.ws.close()

    async def handle_connection(self,websocket):
        try:
            async for message in websocket:
                layers=[]
                numeric=[]
                r=json.loads(message)

                for item in r:
                    if item["type"]=="bar":
                        for mean in item["data"]:
                            numeric.append({"viz_type":"bar","name":mean,"value":item["data"][mean]["value"],"description":item["data"][mean]["description"]})

                    elif item["type"]=="radar":
                        for mean in item["data"]:
                            numeric.append({"viz_type":"radar","name":mean,"value":item["data"][mean]["value"],"description":item["data"][mean]["description"]})

                    else:
                        layers.append(item)

                self._send_indicators(layers,numeric)

        except ConnectionClosed:
            print("Client disconnected")
        except Exception as e:
            print(f"Error: {e}")

    async def start_server(self):
        ws=await server.serve(self.handle_connection,"localhost",8080,max_size=None)
        await ws.wait_closed()

    def start_websocket_server(self):
        asyncio.run(self.start_server())

    async def async_command_answer_handler(self,message:Dict):
        print("Here is the answer to an async command:\t",message)

    async def gama_server_message_handler(self,message:Dict):
        print("Here is the message from Gama-server:\t",message)

    async def gama_client(self):
        client=GamaSyncClient("localhost",8000,self.async_command_answer_handler,self.gama_server_message_handler)
        await client.connect(False)

        project_root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
        gaml_path=os.path.join(project_root,'CS_CityScope_GAMA','models','GameIT','gameit_cityscope.gaml')

        command_answer=client.sync_load(gaml_path,"gameit")

        if "type" in command_answer.keys() and command_answer["type"]==MessageTypes.CommandExecutedSuccessfully.value:
            await client.play(exp_id=command_answer["content"])

        while True:
            await asyncio.sleep(1)

    def start_gama_client(self):
        asyncio.run(self.gama_client())

if __name__=="__main__":
    connection=Brix(table_name='volpe-habm',quietly=True)

    connection.listen()
    connection.stop()
