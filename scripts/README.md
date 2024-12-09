# Significant Changes
## `config.json` File
This file was created to minimize *hardcoding* as much as possible. It is divided into two sections: on the one hand, the standard configuration parameters for **CityIO**, most of which were already present in [MicroBrix](https://colab.research.google.com/drive/1Ulle6CbXMxDUJnQVmsQ6-0yWwgl8Egb3?usp=sharing), and on the other, the configuration parameters for the simulation in **GAMA**.

### Simulation Configuration Parameters in **GAMA**
The following parameters are included:
- `file_path`: This is the relative path, with respect to the `CS_CityScope_GAMA/models` directory, where the simulation file to load will be searched.
- `expt_name`: This is the name of the experiment to run.

### Configuration Parameters in **CityIO**
The following parameters are included:
- `table_name`: This is the name of the *grid*. If omitted, it defaults to `None`.
- `host_mode`: Determines whether `brix.py` should connect to the CityIO server hosted at `cityio.media.mit.edu/cityio` or to a CityIO instance hosted in a **local** Docker container. If omitted, it defaults to `'remote'`, meaning the connection will be established with the server.
- `host_name`: For executions with `"host_mode": "remote"`, this allows replacing the default connection to the usual CityIO server with a different one. If omitted, it defaults to `None`. If `"host_mode": "remote"` is specified but no `host_name` is provided, the connection will still be established with the usual CityIO server.
- `core`, `core_name`, `core_description`, and `core_category`: Define the integration of core modules into the CityScope network. Their default values are `False`, `None`, `None`, and `None`, respectively. For more information, see the documentation on CityIO – Core, available [here](https://cityscope.media.mit.edu/cityio/CityIO%20-%20Core).
- `save`: Specifies whether the content of the messages sent by the modules should be persistently saved. If omitted, it defaults to `False`.

## `brix.py` File
The most important changes are:
- **CityIO** now implements a new type of message. This new message type allows *User Interfaces* to send simulation commands to CityIO and, in turn, for CityIO to redirect them to the modules. These commands currently include *Play* and *Pause*. In the future, the number of available commands is expected to expand.
    > ⚠️ **Warning**: For now, this new message type is **not** deployed in the [CityScopeJS](https://cityscope.media.mit.edu/CS_cityscopeJS/) web interface or in the CityIO server. However, you can review all available commands on the Gama Headless server by clicking [here](https://gama-platform.org/wiki/HeadlessServer#available-commands).
- Execution is now assumed to occur in Docker for both `brix.py` and Gama. Consequently, attempting to use `brix.py` in a local execution environment might lead to errors. For example, `brix.py` will attempt to connect to the Gama Headless server using the following configuration:

    | URL      | Port   |
    | -------- | ------ |
    | `'gama'` | `8000` |

    The DNS services provided by Docker resolve this address, enabling and simplifying communication between `brix.py` and Gama. For more information, click [here](https://docs.docker.com/engine/network/#dns-services).
    To learn more about running both `brix.py` and Gama in Docker, you can consult the following sections, as well as the `Dockerfile` and `docker-compose.yml` files located in the repository's root directory.

## `docker-compose.yml` File
Defines two services:
1. **`gama`**: Based on the `gamaplatform/gama` image, the container is configured as follows:
    - It will be connected to a network named `shared_network`. This network must be created before running the `docker-compose up` command, and is necessary for `brix.py` to communicate with the CityIO instance hosted in a local Docker container.
    - It will have access to the repository's file system, and therefore, to the simulations available within it.
    - It will execute the command `gama -socket 8000` to start the Gama Headless server.
    - It will include a *healthcheck*. Why is this *healthcheck* necessary? `brix.py` will attempt to connect to the Gama Headless server as soon as possible. However, if the server is not yet running, an exception will occur. This *healthcheck* ensures that the Gama Headless server is ready to accept connections.
2. **`brix`**: Based on the description available in the `Dockerfile`, it defines a similar network and file system configuration. In this case, it will execute the `brix.py` script, ensuring that the Gama Headless server is ready to accept connections as per the *healthcheck* explained above.

## `Dockerfile` File
Simply defines the image to be used for the container, creates a Python virtual environment, updates PIP, and installs all the necessary modules to run the `brix.py` script.
