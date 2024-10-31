"""
brix.py

This module defines the Brix class, which facilitates communication with the
CityIO and GAMA systems through WebSockets connections. It includes methods for
starting a WebSocket server, listening for incoming messages, and handling
data exchanges with GAMA headless server.

Key functionalities:
- Connects to the CityIO server to receive and send geospatial data.
- Integrates with the GAMA simulation environment.

Dependencies:
- asyncio
- json
- os
- websockets
- gama_client

"""

import asyncio
import json
import os
from typing import Dict

from websockets.asyncio import client,server
from websockets.exceptions import ConnectionClosed,InvalidHandshake,InvalidURI

from gama_client.message_types import MessageTypes
from gama_client.sync_client import GamaSyncClient

class Brix():
    """Class for managing the connection to CityIO and GAMA."""

    remote_host='cityio.media.mit.edu/cityio'
    geogrid_data={}
    geogrid={}

    def __init__(self,table_name=None,host_mode='remote',host_name=None,core=False,
                core_name=None,core_description=None,core_category=None,save=False):

        if host_name is None:
            self.host=self.remote_host
        else:
            self.host=host_name.strip('/')
        self.host='127.0.0.1:8080' if host_mode=='local' else self.host

        self.save=save
        self.table_name=table_name
        self.core=core
        self.core_name=core_name
        self.core_description=core_description
        self.core_category=core_category
        self.secure_protocol='' if host_mode=='local' else 's'
        self.front_end_url=(
            f'http{self.secure_protocol}://cityio-beta.media.mit.edu/?cityscope={self.table_name}'
        )
        self.cityio_post_url=f'http{self.secure_protocol}://{self.host}/api/table/{table_name}/'
        self.cityio_list=f'http{self.secure_protocol}://{self.host}/api/table/list/'
        self.cityio_wss=f'ws{self.secure_protocol}://{self.host}/module'

        if core:
            self.cityio_wss=self.cityio_wss+'/core'

        self.ws_cityio=None
        self.gama_sync_client=None

    async def _on_message(self,message):
        dict_rec:Dict=json.loads(message)
        message_type=dict_rec['type']
        content:Dict=dict_rec.get('content',{})
        table_name=content.get('tableName')

        if message_type=='TABLE_SNAPSHOT':
            self.geogrid_data[table_name]=content['snapshot']['GEOGRIDDATA']
            self.geogrid[table_name]=content['snapshot']['GEOGRID']

        elif message_type=='GEOGRIDDATA_UPDATE':
            self.geogrid_data[table_name]=content['geogriddata']

        elif self.core and message_type in {'SUBSCRIPTION_REQUEST','SUBSCRIPTION_REMOVAL_REQUEST'}:
            action="SUBSCRIBE" if message_type=='SUBSCRIPTION_REQUEST' else "UNSUBSCRIBE"
            await self._send_message({"type":action,"content":{"gridId":content['table']}})

    async def _on_open(self):
        print("## Opened connection")
        message_type="CORE_MODULE_REGISTRATION" if self.core else "SUBSCRIBE"
        content=({"name":self.core_name,"description":self.core_description,
            "moduleType":self.core_category} if self.core else {"gridId":self.table_name
        })
        await self._send_message({"type":message_type,"content":content})

    async def _send_message(self,message:Dict):
        await self.ws_cityio.send(json.dumps(message))

    async def _send_indicators(self,layers,numeric):
        message={
            "type":"MODULE","content":{"gridId":self.table_name,"save":self.save,"moduleData":{}}
        }

        if layers is not None:
            message["content"]["moduleData"]["layers"]=layers

        if numeric is not None:
            message["content"]["moduleData"]["numeric"]=numeric

        await self._send_message(message)

    async def listen(self):
        """Connects to the CityIO server and listens for incoming messages."""
        try:
            async with client.connect(uri=self.cityio_wss,max_size=None) as self.ws_cityio:
                await self._on_open()
                try:
                    while True:
                        await self._on_message(await self.ws_cityio.recv())

                except ConnectionClosed:
                    print("## Connection closed")

                await self.ws_cityio.wait_closed()
        except (InvalidURI,OSError,InvalidHandshake,TimeoutError) as e:
            print(f"Error:{e}")

    async def _handle_gama_connection(self,websocket):
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
                            numeric.append({
                                "viz_type":item_type,"name":mean,"value":item_data[mean]["value"],
                                "description":item_data[mean]["description"]
                            })
                    else:
                        layers.append(item)

                await self._send_indicators(layers,numeric)

        except ConnectionClosed:
            print("Client disconnected")

    async def start_server(self):
        """Starts a WebSocket server to handle connections from GAMA Networking_Client agent."""
        ws=await server.serve(
            handler=self._handle_gama_connection,host="localhost",port=8080,max_size=None
        )
        await ws.wait_closed()

    async def _async_command_answer_handler(self,message:Dict):
        print("Here is the answer to an async command:\t",message)

    async def _gama_server_message_handler(self,message:Dict):
        print("Here is the message from Gama-server:\t",message)

    async def gama_sync(self):
        """Connects to the GAMA headless server and plays a GAML model."""
        self.gama_sync_client=GamaSyncClient(
            url="localhost",port=8000,async_command_handler=self._async_command_answer_handler,
            other_message_handler=self._gama_server_message_handler
        )
        await self.gama_sync_client.connect(False)

        project_root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
        gaml_path=os.path.join(
            project_root,'CS_CityScope_GAMA','models','GameIT','gameit_cityscope.gaml'
        )

        command_answer=self.gama_sync_client.sync_load(gaml_path,"gameit")

        if command_answer.get("type")==MessageTypes.CommandExecutedSuccessfully.value:
            await self.gama_sync_client.play(exp_id=command_answer["content"])

        while True:
            await asyncio.sleep(1)

if __name__=="__main__":
    connection=Brix(table_name='volpe-habm')

    try:
        asyncio.run(
            asyncio.gather(connection.start_server(),connection.listen(),connection.gama_sync())
        )
    except KeyboardInterrupt:
        print("Bye!")
