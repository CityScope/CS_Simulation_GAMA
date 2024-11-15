# Instructions for Use

1. Copy and search for [this link](https://cityscope.media.mit.edu/CS_cityscopeJS/?cityscope=volpe-habm) in your browser.

2. Located in the folder `CS_Simulation_GAMA/scripts`, install all necessary modules using `pip install -r requirements.txt`. During this step, the error
    ```
    ERROR: Cannot install gama-client==1.2.0 and websockets==13.1 because these package versions have conflicting dependencies.
    ```
    may appear. To resolve this, you can first install `gama_client` using
    ```bash
    pip install gama-client==1.2.0
    ```
    and then update `websockets` using
    ```bash
    pip install websockets==13.1
    ```
    Finally, do not forget to install `nest-asyncio` using
    ```bash
    pip install nest-asyncio==1.6.0
    ```

3. In the `/headless` folder of your GAMA installation, start GAMA in headless mode on port 8000, i.e.,
    ```bash
    .\gama-headless.bat -socket 8000
    ```
    on Windows or
    ```bash
    gama-headless.sh -socket 8000
    ```
    on Linux/Mac OS.

4. Run the `brix.py` script located in the `CS_Simulation_GAMA/scripts` folder.

If everything works as expected, the agents of the people species will appear on the screen, and the transport usage for every means of transportation will be graphed in the radar and bar charts.
