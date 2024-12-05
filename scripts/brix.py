"""
brix.py

This module defines the Brix class, which facilitates communication with the CityIO and GAMA systems
through WebSockets connections. It includes methods for starting a WebSocket server, listening for
incoming messages, and handling data exchanges with GAMA headless server.

Key functionalities:
- Connects to the CityIO server to receive and send geospatial data.
- Integrates with the GAMA simulation environment.

Dependencies:
- asyncio
- json
- os
- typing
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

    def __init__(self,config_file='config.json'):
        with open(os.path.join(os.sep,'scripts',config_file),'r',encoding='utf-8') as f:
            self.config:Dict=json.load(f)

        self.cityio_config:Dict=self.config.get('cityio',{})
        self.table_name=self.cityio_config.get('table_name',None)
        self.core=self.cityio_config.get('core',False)

        self.ws_cityio=None
        self.gama_sync_client=None
        self.load_answer=None

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

        elif message_type=='UPDATE_MODULE':
            command=content['payload']
            if command=='Play':
                if self.load_answer.get('type')==MessageTypes.CommandExecutedSuccessfully.value:
                    await self.gama_sync_client.play(exp_id=self.load_answer['content'])

            elif command=='Pause':
                await self.gama_sync_client.pause(exp_id=self.load_answer['content'])

        elif self.core and message_type in {'SUBSCRIPTION_REQUEST','SUBSCRIPTION_REMOVAL_REQUEST'}:
            action='SUBSCRIBE' if message_type=='SUBSCRIPTION_REQUEST' else 'UNSUBSCRIBE'
            await self._send_message({'type':action,'content':{'gridId':content['table']}})

    async def _on_open(self):
        print('## Opened connection')
        message_type='CORE_MODULE_REGISTRATION' if self.core else 'SUBSCRIBE'

        content={
            'name':self.cityio_config.get('core_name',None),
            'description':self.cityio_config.get('core_description',None),
            'moduleType':self.cityio_config.get('core_category',None)
        } if self.core else {'gridId':self.table_name}

        await self._send_message({'type':message_type,'content':content})

    async def _send_message(self,message:Dict):
        await self.ws_cityio.send(json.dumps(message))

    async def _send_indicators(self,layers,numeric):
        message={
            'type':'MODULE',
            'content':{
                'gridId':self.table_name,
                'save':self.cityio_config.get('save',False),
                'moduleData':{}
            }
        }

        if layers is not None:
            message['content']['moduleData']['layers']=layers

        if numeric is not None:
            message['content']['moduleData']['numeric']=numeric

        await self._send_message(message)

    async def listen(self):
        """Connects to the CityIO server and listens for incoming messages."""
        host_mode=self.cityio_config.get('host_mode','remote')
        host_name=self.cityio_config.get('host_name',None)

        host='cityio:8080' if host_mode=='local' else (
            host_name.strip('/') if host_name is not None else self.remote_host
        )
        secure_protocol='' if host_mode=='local' else 's'
        cityio_wss=f'ws{secure_protocol}://{host}/module'+('/core' if self.core else '')

        try:
            async with client.connect(uri=cityio_wss,max_size=None) as self.ws_cityio:
                try:
                    await self._on_open()
                    while True:
                        await self._on_message(await self.ws_cityio.recv())

                except ConnectionClosed:
                    print('## Connection closed')

                await self.ws_cityio.wait_closed()

        except (InvalidURI,OSError,InvalidHandshake,TimeoutError) as e:
            print(f'Error:{e}')

    async def _gama_connt(self,websocket):
        try:
            async for message in websocket:
                layers=[]
                numeric=[]
                r=json.loads(message)

                for item in r:
                    item_type=item['type']
                    item_data=item['data']

                    if item_type in {'bar','radar'}:
                        for mean in item_data:
                            numeric.append({
                                'viz_type':item_type,
                                'name':mean,
                                'value':item_data[mean]['value'],
                                'description':item_data[mean]['description']
                            })
                    else:
                        layers.append(item)

                await self._send_indicators(layers,numeric)

        except ConnectionClosed:
            print('Client disconnected')

    async def start_server(self):
        """Starts a WebSocket server to handle connections from GAMA Networking_Client agent."""
        ws=await server.serve(handler=self._gama_connt,host='0.0.0.0',port=8001,max_size=None)
        await ws.serve_forever()

    async def _async_cmd_ans(self,message:Dict):
        print('Here is the answer to an async command:\t',message)

    async def _gama_svr_msg(self,message:Dict):
        print('Here is the message from Gama-server:\t',message)

    async def gama_sync(self):
        """Connects to the GAMA headless server and plays a GAML model."""
        gsc_config:Dict=self.config.get('gama_sync_client',{})
        self.gama_sync_client=GamaSyncClient(
            url=os.getenv('Gama_IMAGE',gsc_config.get('host')),port=gsc_config.get('port'),
            async_command_handler=self._async_cmd_ans,other_message_handler=self._gama_svr_msg
        )
        await self.gama_sync_client.connect(False)

        gaml_path=os.path.join(self.project_root if os.getenv('Gama_IMAGE') is None else os.sep,
            'CS_CityScope_GAMA','models',gsc_config.get('file_path')
        )
        self.load_answer=self.gama_sync_client.sync_load(gaml_path,gsc_config.get('expt_name'))

        while True:
            await asyncio.sleep(1)

if __name__=='__main__':
    connt=Brix()

    try:
        asyncio.run(asyncio.gather(connt.start_server(),connt.listen(),connt.gama_sync()))

    except KeyboardInterrupt:
        print('Bye!')
