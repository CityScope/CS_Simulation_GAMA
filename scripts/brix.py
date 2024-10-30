import asyncio
import json
import os
from typing import Dict

from websockets.asyncio import client,server
from websockets.exceptions import ConnectionClosed,InvalidHandshake,InvalidURI

from gama_client.message_types import MessageTypes
from gama_client.sync_client import GamaSyncClient

class Brix():

    remote_host='cityio.media.mit.edu/cityio'
    geogrid_data={}
    geogrid={}

    def __init__(self,table_name=None,quietly=False,host_mode='remote',host_name=None,
        core=False,core_name=None,core_description=None,core_category=None,save=False):

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
        self.ws=None

    async def on_message(self,message):
        dict_rec=json.loads(message)
        message_type=dict_rec['type']
        content=dict_rec.get('content',{})
        table_name=content.get('tableName')

        if message_type=='TABLE_SNAPSHOT':
            self.geogrid_data[table_name]=content['snapshot']['GEOGRIDDATA']
            self.geogrid[table_name]=content['snapshot']['GEOGRID']

        elif message_type=='GEOGRIDDATA_UPDATE':
            self.geogrid_data[table_name]=content['geogriddata']

        elif self.core and message_type in {'SUBSCRIPTION_REQUEST','SUBSCRIPTION_REMOVAL_REQUEST'}:
            action="SUBSCRIBE" if message_type=='SUBSCRIPTION_REQUEST' else "UNSUBSCRIBE"
            await self.send_message({"type":action,"content":{"gridId":content['table']}})

    async def on_open(self):
        print("## Opened connection")
        message_type="CORE_MODULE_REGISTRATION" if self.core else "SUBSCRIBE"
        content=(
            {"name":self.core_name,"description":self.core_description,"moduleType":self.core_category}
            if self.core else {"gridId":self.table_name}
        )
        await self.send_message({"type":message_type,"content":content})

    async def send_message(self,message:Dict):
        await self.ws.send(json.dumps(message))

    async def _send_indicators(self,layers,numeric):
        message={"type":"MODULE","content":{"gridId":self.table_name,"save":self.save,"moduleData":{}}}

        if layers is not None:
            message["content"]["moduleData"]["layers"]=layers

        if numeric is not None:
            message["content"]["moduleData"]["numeric"]=numeric

        await self.send_message(message)

    async def listen(self):
        try:
            self.ws=await client.connect(uri=self.cityIO_wss)
            await self.ws.wait_closed()
        except (InvalidURI,OSError,InvalidHandshake,TimeoutError) as e:
            print(f"Error:{e}")

    async def handle_connection(self,websocket):
        try:
            async for message in websocket:
                layers=[]
                numeric=[]
                r=json.loads(message)

                for item in r:
                    item_type=item["type"]
                    item_data=item["data"]

                    if item_type in {"bar","radar"}:
                        for mean in item_data:
                            numeric.append({"viz_type":item_type,"name":mean,"value":item_data[mean]["value"],
                                            "description":item_data[mean]["description"]})
                    else:
                        layers.append(item)

                await self._send_indicators(layers,numeric)

        except ConnectionClosed:
            print("Client disconnected")
        except Exception as e:
            print(f"Error:{e}")

    async def start_server(self):
        ws=await server.serve(handler=self.handle_connection,host="localhost",port=8080,max_size=None)
        await ws.wait_closed()

    async def async_command_answer_handler(self,message:Dict):
        print("Here is the answer to an async command:\t",message)

    async def gama_server_message_handler(self,message:Dict):
        print("Here is the message from Gama-server:\t",message)

    async def gama_client(self):
        client=GamaSyncClient(url="localhost",port=8000,async_command_handler=self.async_command_answer_handler,other_message_handler=self.gama_server_message_handler)
        await client.connect(False)

        project_root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
        gaml_path=os.path.join(project_root,'CS_CityScope_GAMA','models','GameIT','gameit_cityscope.gaml')

        command_answer=client.sync_load(gaml_path,"gameit")

        if command_answer.get("type")==MessageTypes.CommandExecutedSuccessfully.value:
            await client.play(exp_id=command_answer["content"])

        while True:
            await asyncio.sleep(1)

if __name__=="__main__":
    connection=Brix(table_name='volpe-habm',quietly=True)
    asyncio.run(asyncio.gather(connection.gama_client(),connection.start_server(),connection.listen()))
