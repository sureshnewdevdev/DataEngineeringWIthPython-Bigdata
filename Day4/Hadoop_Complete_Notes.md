# Hadoop — Complete Notes & Practicals for Freshers

> A zero-to-hands-on guide. Read the theory, then do every practical in order. Everything here targets **Hadoop 3.x** (the current standard) on **Linux/Ubuntu**, with notes where Hadoop 2.x differs.

---

## Table of Contents

**PART A — THEORY**
1. Big Data — the problem Hadoop solves
2. What is Hadoop?
3. The Hadoop ecosystem (the family of tools)
4. HDFS — the storage layer
5. YARN — the resource manager
6. MapReduce — the processing model

**PART B — SETUP (all scenarios)**
7. Scenario 0 — Prerequisites (Java, SSH, user)
8. Scenario 1 — Standalone (Local) mode
9. Scenario 2 — Pseudo-Distributed mode (single machine, full cluster feel)
10. Scenario 3 — Fully-Distributed mode (real multi-node cluster)

**PART C — PRACTICALS**
11. HDFS command practicals (every common command)
12. MapReduce practical — run the built-in example
13. MapReduce practical — write your own WordCount in Java
14. MapReduce practical — Hadoop Streaming with Python
15. Hive practical (SQL on Hadoop)
16. Pig practical (dataflow scripting)
17. Sqoop practical (import/export from databases)
18. HBase practical (NoSQL on Hadoop)
19. Spark practical (fast in-memory processing)

**PART D — REFERENCE**
20. Common errors & fixes
21. Interview quick-revision sheet
22. Practice exercises (do these yourself)

---
---

# PART A — THEORY

## 1. Big Data — the problem Hadoop solves

Traditional systems (a single powerful server + a relational database) break down when data becomes too **big**, arrives too **fast**, or comes in too many **shapes**. This is described by the **"V"s of Big Data**:

- **Volume** — terabytes to petabytes of data. One machine can't store it.
- **Velocity** — data arrives continuously and fast (clicks, sensors, logs).
- **Variety** — structured (tables), semi-structured (JSON, XML, logs), and unstructured (images, video, text).
- **Veracity** — data quality/trustworthiness varies.
- **Value** — the whole point: extracting something useful.

**The core idea Hadoop introduced:** instead of buying one giant expensive machine (*vertical scaling*), use **many cheap commodity machines working together** (*horizontal scaling*). And instead of moving huge data across the network to the program, **move the small program to where the data already lives** ("data locality").

---

## 2. What is Hadoop?

**Hadoop** is an open-source framework (Apache project, originally inspired by Google's GFS and MapReduce papers) for **storing and processing very large datasets across clusters of commodity computers**.

It is built to be:
- **Distributed** — data and computation spread across many nodes.
- **Scalable** — add more nodes to handle more data.
- **Fault-tolerant** — if a machine dies, the system keeps working (data is replicated).
- **Cost-effective** — runs on ordinary hardware.

### The 3 core components

| Component | Role | One-line description |
|-----------|------|----------------------|
| **HDFS** | Storage | Distributed file system that splits files into blocks and spreads copies across nodes. |
| **YARN** | Resource management | Decides which node runs which job and how much CPU/memory it gets. |
| **MapReduce** | Processing | Programming model to process data in parallel across the cluster. |

Think of it as: **HDFS stores** the data, **YARN allocates** the resources, **MapReduce (or Spark, etc.) processes** the data.

### Master–Slave architecture (the mental model)

Hadoop uses a **master/slave** design:
- **Master daemons** coordinate and hold metadata (NameNode, ResourceManager).
- **Slave (worker) daemons** do the actual storing and computing (DataNode, NodeManager).

---

## 3. The Hadoop ecosystem (the family of tools)

Hadoop by itself is HDFS + YARN + MapReduce. Around it grew a whole ecosystem:

| Tool | What it does | Analogy |
|------|--------------|---------|
| **HDFS** | Distributed storage | The hard disk of the cluster |
| **YARN** | Resource/job scheduling | The operating system |
| **MapReduce** | Batch processing | The classic engine |
| **Hive** | SQL queries on Hadoop (HiveQL) | SQL for big data |
| **Pig** | Dataflow scripting (Pig Latin) | Scripting for ETL |
| **HBase** | NoSQL column database on HDFS | Real-time random reads/writes |
| **Sqoop** | Move data between Hadoop and RDBMS | Import/export bridge |
| **Flume** | Ingest streaming/log data into HDFS | Log collector |
| **Oozie** | Workflow scheduler | Cron for Hadoop jobs |
| **ZooKeeper** | Coordination service | The referee for distributed systems |
| **Spark** | Fast in-memory processing | MapReduce's faster successor |

You don't need all of them. Freshers should be solid on **HDFS + YARN + MapReduce + Hive + Sqoop + Spark basics**.

---

## 4. HDFS — the storage layer

**HDFS = Hadoop Distributed File System.** It stores huge files by splitting them into **blocks** and distributing those blocks (with copies) across many machines.

### Key concepts

- **Block**: A file is split into fixed-size blocks. **Default block size = 128 MB** in Hadoop 2.x/3.x (it was 64 MB in Hadoop 1.x). A 500 MB file → 4 blocks (128+128+128+116 MB). Large block size reduces the number of blocks the NameNode must track and improves throughput.
- **Replication**: Each block is copied to multiple nodes. **Default replication factor = 3.** So the cluster can lose 2 copies of a block and still recover.
- **Write-once, read-many**: HDFS is optimized for writing a file once and reading it many times (append is limited). It is **not** for low-latency random edits — that's what HBase is for.

### The daemons (processes)

**NameNode (Master)**
- Stores the **metadata**: the file→block mapping, directory tree, permissions, and which DataNodes hold which blocks.
- Does **not** store the actual file data.
- Keeps metadata in two files: **`fsimage`** (a snapshot) and **`edits`** (a running log of changes).
- If the NameNode is lost and not backed up, the whole filesystem is unreadable → it is a **single point of failure** (solved in production by **HDFS High Availability** with a standby NameNode + ZooKeeper).

**DataNode (Slave/Worker)**
- Stores the **actual data blocks** on local disk.
- Sends a **heartbeat** to the NameNode (every 3 seconds by default) to say "I'm alive," and a periodic **block report** listing the blocks it holds.
- If a DataNode stops sending heartbeats, the NameNode marks it dead and re-replicates its blocks elsewhere.

**Secondary NameNode**
- **NOT a backup or failover** for the NameNode (common misconception!).
- Its job is **checkpointing**: it periodically merges the `fsimage` and `edits` log into a fresh `fsimage`, so the edits log doesn't grow forever and NameNode restarts stay fast.

### How an HDFS write works (simplified)
1. Client asks the NameNode to create a file.
2. NameNode checks permissions/space, returns a list of DataNodes for the first block.
3. Client writes the block to the first DataNode, which **pipelines** copies to the next DataNodes (for replication).
4. DataNodes acknowledge; client moves to the next block.
5. When done, the file is closed and metadata is committed on the NameNode.

### Rack awareness
Hadoop knows which physical **rack** a node is on. Default replica placement: one replica on the local node, one on a node in a **different** rack, and the third on another node in that same different rack. This balances **fault tolerance** (survive a whole rack failing) with **network efficiency**.

---

## 5. YARN — the resource manager

**YARN = Yet Another Resource Negotiator.** Introduced in Hadoop 2.x, it separates *resource management* from *data processing*, so Hadoop can run MapReduce, Spark, Tez, and more on the same cluster.

### The daemons

**ResourceManager (Master)** — one per cluster. Has two parts:
- **Scheduler**: decides which application gets resources (memory/CPU), based on a policy (Capacity Scheduler, Fair Scheduler).
- **ApplicationsManager**: accepts job submissions and launches the ApplicationMaster for each job.

**NodeManager (Slave)** — one per worker node. Manages **containers** on that node, monitors their resource usage (CPU, memory), and reports back to the ResourceManager.

**ApplicationMaster** — one **per application/job**. Negotiates containers from the ResourceManager and coordinates the job's tasks. (So YARN doesn't have one central bottleneck managing every task.)

**Container** — a bundle of resources (e.g., 2 GB RAM + 1 CPU core) on a node where an actual task runs.

### How a job runs on YARN (simplified)
1. Client submits an application to the **ResourceManager**.
2. RM allocates a container and starts the **ApplicationMaster** for that job.
3. The ApplicationMaster requests more containers from the RM for the actual tasks.
4. **NodeManagers** launch those containers and run the tasks.
5. The ApplicationMaster monitors tasks, handles failures/retries, and reports progress.
6. On completion, resources are released.

---

## 6. MapReduce — the processing model

**MapReduce** is a programming model for processing large data in parallel. You write two functions:

- **Map**: takes input, emits intermediate **key–value pairs**.
- **Reduce**: takes all values grouped by key, and produces the final output.

Between them, the framework does **Shuffle & Sort** automatically.

### The classic example — WordCount
Count how often each word appears across huge text files.

- **Map**: for each word, emit `(word, 1)`.
  - Input line `"cat dog cat"` → `(cat,1) (dog,1) (cat,1)`
- **Shuffle & Sort**: group all values by key → `cat -> [1,1]`, `dog -> [1]`.
- **Reduce**: sum the values → `(cat, 2) (dog, 1)`.

### The full pipeline

```
Input file
   ↓  (InputFormat splits file into Input Splits)
Input Split → RecordReader → key/value records
   ↓
[MAP TASK]  your map() runs on each record → intermediate (k,v)
   ↓
Combiner (optional "mini-reducer" — runs locally to cut network traffic)
   ↓
Partitioner (decides which reducer each key goes to; default = hash(key) % numReducers)
   ↓
=== SHUFFLE & SORT ===  (framework moves data to reducers, sorts by key)
   ↓
[REDUCE TASK]  your reduce() runs per key with all its values
   ↓
OutputFormat → writes results to HDFS (part-r-00000, etc.)
```

### Key terms
- **Input Split**: a logical chunk of input given to one map task (roughly one HDFS block).
- **Combiner**: optional local aggregation after map to reduce data shuffled. Must be safe to run zero, one, or many times (works for sum/count, not for average unless careful).
- **Partitioner**: routes keys to reducers so the same key always goes to the same reducer.
- **Number of mappers** ≈ number of input splits. **Number of reducers** is set by you.
- **Output**: one file per reducer, named `part-r-00000`, `part-r-00001`, etc.

MapReduce is **batch-oriented and disk-heavy**, which is why **Spark** (in-memory) largely replaced it for new workloads — but understanding MapReduce is foundational.

---
---

# PART B — SETUP (all scenarios)

Hadoop can run in **three modes**. A fresher should know all three:

| Mode | Daemons? | Storage used | Use case |
|------|----------|--------------|----------|
| **Standalone (Local)** | No daemons; single JVM | Local filesystem | Learning MapReduce logic, debugging |
| **Pseudo-Distributed** | All daemons, each in its own JVM, on **one** machine | HDFS | Learning the full cluster experience on a laptop |
| **Fully-Distributed** | Daemons spread across **many** machines | HDFS | Real production clusters |

---

## 7. Scenario 0 — Prerequisites (do this before any mode)

> Assumes Ubuntu/Debian Linux. On Windows, use **WSL2** (Windows Subsystem for Linux) or a Linux VM — do not fight native Windows Hadoop as a beginner.

### Step 1 — Update the system
```bash
sudo apt update && sudo apt upgrade -y
```

### Step 2 — Install Java (Hadoop 3.x needs Java 8 or Java 11)
```bash
sudo apt install openjdk-11-jdk -y
java -version          # verify: should print openjdk version "11..."
```

Find where Java is installed (you'll need JAVA_HOME):
```bash
readlink -f $(which java)
# Example output: /usr/lib/jvm/java-11-openjdk-amd64/bin/java
# So JAVA_HOME = /usr/lib/jvm/java-11-openjdk-amd64
```

### Step 3 — (Recommended) Create a dedicated hadoop user
Keeps Hadoop isolated from your personal account.
```bash
sudo adduser hadoop          # set a password when prompted
sudo usermod -aG sudo hadoop # give it sudo rights
su - hadoop                  # switch into the hadoop user
```

### Step 4 — Install and configure SSH (needed so Hadoop can start daemons)
Even on one machine, Hadoop uses SSH to launch its daemons. Set up **passwordless SSH to localhost**:
```bash
sudo apt install openssh-server openssh-client -y

# Generate a key pair (press Enter at all prompts to accept defaults / empty passphrase)
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa

# Authorize your own key
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Test — this must connect WITHOUT asking for a password
ssh localhost
exit
```
If `ssh localhost` still asks for a password, passwordless SSH isn't set up and Hadoop won't start cleanly.

### Step 5 — Download and extract Hadoop
```bash
cd ~
# Download (check https://hadoop.apache.org/releases.html for the latest 3.x version/mirror)
wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz

tar -xzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 ~/hadoop        # rename for convenience
```

### Step 6 — Set environment variables
Edit `~/.bashrc`:
```bash
nano ~/.bashrc
```
Add these lines at the bottom (adjust JAVA_HOME to your path from Step 2):
```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/home/hadoop/hadoop
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
```
Apply the changes:
```bash
source ~/.bashrc
hadoop version     # verify: should print Hadoop 3.3.6
```

### Step 7 — Tell Hadoop where Java is
Edit `$HADOOP_HOME/etc/hadoop/hadoop-env.sh` and set JAVA_HOME explicitly (Hadoop sometimes doesn't pick it up from the shell):
```bash
nano $HADOOP_HOME/etc/hadoop/hadoop-env.sh
```
Find the `# export JAVA_HOME=` line and set:
```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
```

✅ Prerequisites complete. Now pick a mode.

---

## 8. Scenario 1 — Standalone (Local) mode

This is the **default** mode right after extraction. **No daemons run, no HDFS** — Hadoop just runs MapReduce as a single Java process on your local files. Perfect for testing MapReduce logic.

No config changes are needed. Test it with the built-in example (grep):
```bash
cd ~/hadoop
mkdir input
cp etc/hadoop/*.xml input          # use the XML config files as sample text
# Find all words matching the pattern 'dfs[a-z.]+' and count them
bin/hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar grep input output 'dfs[a-z.]+'
cat output/*                        # see the result
rm -r output                        # output dir must not exist before a new run
```
If you see word→count output, standalone mode works. Notice it read from the **local** `input` folder, not HDFS.

---

## 9. Scenario 2 — Pseudo-Distributed mode

All Hadoop daemons run on **one machine**, each in its own JVM, and data lives in **HDFS**. This is what most freshers use to learn. You'll edit 4 config files in `$HADOOP_HOME/etc/hadoop/`.

### Step 1 — core-site.xml (where the NameNode/filesystem is)
```bash
nano $HADOOP_HOME/etc/hadoop/core-site.xml
```
```xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
```

### Step 2 — hdfs-site.xml (replication + where blocks/metadata are stored)
On a single machine, replication must be 1 (you only have one DataNode).
```bash
nano $HADOOP_HOME/etc/hadoop/hdfs-site.xml
```
```xml
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///home/hadoop/hadoopdata/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///home/hadoop/hadoopdata/hdfs/datanode</value>
    </property>
</configuration>
```
Create those directories:
```bash
mkdir -p ~/hadoopdata/hdfs/namenode ~/hadoopdata/hdfs/datanode
```

### Step 3 — mapred-site.xml (use YARN for MapReduce)
```bash
nano $HADOOP_HOME/etc/hadoop/mapred-site.xml
```
```xml
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
```

### Step 4 — yarn-site.xml
```bash
nano $HADOOP_HOME/etc/hadoop/yarn-site.xml
```
```xml
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
    </property>
</configuration>
```

### Step 5 — Format the NameNode (ONE TIME ONLY)
This initializes HDFS metadata. **Do it only once** — reformatting a running cluster erases everything.
```bash
hdfs namenode -format
```
Look for `Storage directory ... has been successfully formatted`.

### Step 6 — Start the daemons
```bash
start-dfs.sh      # starts NameNode, DataNode, Secondary NameNode
start-yarn.sh     # starts ResourceManager, NodeManager
```

### Step 7 — Verify with jps
`jps` lists running Java processes. You should see **all 5 (+ Jps)**:
```bash
jps
```
Expected:
```
NameNode
DataNode
SecondaryNameNode
ResourceManager
NodeManager
Jps
```
If any is missing, check its log in `$HADOOP_HOME/logs/`.

### Step 8 — Open the Web UIs (Hadoop 3.x ports)
- **NameNode / HDFS**: http://localhost:9870   *(Hadoop 2.x used 50070)*
- **ResourceManager / YARN**: http://localhost:8088
- **Secondary NameNode**: http://localhost:9868
- **DataNode**: http://localhost:9864

### Step 9 — Stop the daemons (when done)
```bash
stop-yarn.sh
stop-dfs.sh
```

✅ You now have a working single-node "cluster." Go to **Part C** for practicals.

---

## 10. Scenario 3 — Fully-Distributed mode (real cluster)

Now across **multiple machines**. Example: 1 master + 2 workers.

| Host | Role / daemons |
|------|----------------|
| `master` (e.g., 192.168.1.10) | NameNode, ResourceManager, SecondaryNameNode |
| `worker1` (192.168.1.11) | DataNode, NodeManager |
| `worker2` (192.168.1.12) | DataNode, NodeManager |

### Step 1 — On EVERY node
Do all of **Scenario 0** (same Java version, same `hadoop` user, same Hadoop version, same install path) on every machine.

### Step 2 — Set hostnames and /etc/hosts (every node)
```bash
sudo nano /etc/hosts
```
Add (use your real IPs) on **all** nodes:
```
192.168.1.10   master
192.168.1.11   worker1
192.168.1.12   worker2
```

### Step 3 — Passwordless SSH from master to all workers
On **master** (as the hadoop user), copy the master's public key to each worker:
```bash
ssh-copy-id hadoop@master
ssh-copy-id hadoop@worker1
ssh-copy-id hadoop@worker2
# Test each — must connect without a password:
ssh worker1   # then exit
ssh worker2   # then exit
```

### Step 4 — Config files (same on all nodes; keep them identical)

**core-site.xml** — point everything at the master:
```xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://master:9000</value>
    </property>
</configuration>
```

**hdfs-site.xml** — replication 2 or 3 (you now have multiple DataNodes):
```xml
<configuration>
    <property><name>dfs.replication</name><value>2</value></property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///home/hadoop/hadoopdata/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///home/hadoop/hadoopdata/hdfs/datanode</value>
    </property>
</configuration>
```

**yarn-site.xml** — tell workers where the ResourceManager is:
```xml
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>master</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
```

**mapred-site.xml** — same as pseudo-distributed (`mapreduce.framework.name = yarn`).

### Step 5 — List the workers (on the master only)
In Hadoop 3.x, edit `$HADOOP_HOME/etc/hadoop/workers` (in Hadoop 2.x this file was called `slaves`):
```bash
nano $HADOOP_HOME/etc/hadoop/workers
```
```
worker1
worker2
```
(Remove `localhost` if present, unless the master should also store data.)

### Step 6 — Format the NameNode (on master only, once)
```bash
hdfs namenode -format
```

### Step 7 — Start the cluster (from master)
The master's start scripts SSH into the workers and start their daemons automatically:
```bash
start-dfs.sh
start-yarn.sh
```

### Step 8 — Verify
On **master**, `jps` should show `NameNode`, `SecondaryNameNode`, `ResourceManager`.
On each **worker**, `jps` should show `DataNode`, `NodeManager`.
Then check the NameNode UI at **http://master:9870** — the "Datanodes" tab should list both workers as live.

✅ You now have a real distributed cluster. All the Part C practicals work identically — HDFS just spreads the blocks across the workers.

---
---

# PART C — PRACTICALS

> Make sure your daemons are running (`jps` shows the 5 processes). All HDFS commands use `hdfs dfs -<command>` (older syntax `hadoop fs -<command>` also works).

## 11. HDFS command practicals

### Setup — create your home directory in HDFS
```bash
hdfs dfs -mkdir -p /user/hadoop
```

### Create directories
```bash
hdfs dfs -mkdir /user/hadoop/data
hdfs dfs -mkdir -p /user/hadoop/project/logs   # -p makes parent dirs
```

### List files
```bash
hdfs dfs -ls /                      # list root
hdfs dfs -ls /user/hadoop           # list a folder
hdfs dfs -ls -R /user/hadoop        # recursive listing
```

### Put (upload) files from local → HDFS
```bash
echo "hello hadoop world hello big data" > sample.txt
hdfs dfs -put sample.txt /user/hadoop/data/
# -copyFromLocal does the same thing:
hdfs dfs -copyFromLocal sample.txt /user/hadoop/data/sample2.txt
```

### Read file contents
```bash
hdfs dfs -cat /user/hadoop/data/sample.txt     # print whole file
hdfs dfs -tail /user/hadoop/data/sample.txt     # last 1 KB
hdfs dfs -head /user/hadoop/data/sample.txt     # first 1 KB (Hadoop 3.1+)
```

### Get (download) files from HDFS → local
```bash
hdfs dfs -get /user/hadoop/data/sample.txt ./downloaded.txt
# -copyToLocal is the same:
hdfs dfs -copyToLocal /user/hadoop/data/sample.txt ./downloaded2.txt
```

### Copy and move WITHIN HDFS
```bash
hdfs dfs -cp /user/hadoop/data/sample.txt /user/hadoop/project/
hdfs dfs -mv /user/hadoop/data/sample2.txt /user/hadoop/project/
```

### Delete files and directories
```bash
hdfs dfs -rm /user/hadoop/project/sample2.txt        # delete a file
hdfs dfs -rm -r /user/hadoop/project/logs            # delete a directory
hdfs dfs -rm -r -skipTrash /user/hadoop/olddata      # permanent delete (skip trash)
```

### Disk usage & filesystem info
```bash
hdfs dfs -du -h /user/hadoop           # size of each item (human readable)
hdfs dfs -df -h                        # free/used space in HDFS
hdfs dfs -count /user/hadoop           # dir count, file count, total size
```

### Permissions & ownership
```bash
hdfs dfs -chmod 755 /user/hadoop/data/sample.txt
hdfs dfs -chown hadoop:hadoop /user/hadoop/data/sample.txt
```

### Change replication factor of an existing file
```bash
hdfs dfs -setrep -w 2 /user/hadoop/data/sample.txt   # -w waits until done
```

### Check the health of the filesystem (fsck)
```bash
hdfs fsck /user/hadoop/data/sample.txt -files -blocks -locations
```
This shows the file's blocks and which DataNodes hold each replica — great for *seeing* how HDFS distributes data.

### Admin report (cluster health)
```bash
hdfs dfsadmin -report      # live nodes, capacity, used/remaining
```

### Quick reference table

| Task | Command |
|------|---------|
| Make dir | `hdfs dfs -mkdir -p /path` |
| Upload | `hdfs dfs -put localfile /path` |
| Download | `hdfs dfs -get /path/file .` |
| List | `hdfs dfs -ls /path` |
| Read | `hdfs dfs -cat /path/file` |
| Delete file | `hdfs dfs -rm /path/file` |
| Delete dir | `hdfs dfs -rm -r /path` |
| Copy in HDFS | `hdfs dfs -cp src dst` |
| Move in HDFS | `hdfs dfs -mv src dst` |
| Disk usage | `hdfs dfs -du -h /path` |
| Set replication | `hdfs dfs -setrep 2 /path/file` |
| Health check | `hdfs fsck /path -files -blocks` |

---

## 12. MapReduce practical — run the built-in WordCount

Hadoop ships example jobs. Let's run WordCount on real HDFS data.

### Step 1 — Create input data in HDFS
```bash
mkdir -p ~/wc_input
echo "cat dog cat bird dog cat" > ~/wc_input/file1.txt
echo "bird bird fish cat dog"   > ~/wc_input/file2.txt

hdfs dfs -mkdir -p /user/hadoop/wordcount/input
hdfs dfs -put ~/wc_input/*.txt /user/hadoop/wordcount/input/
hdfs dfs -ls /user/hadoop/wordcount/input
```

### Step 2 — Run the example jar
```bash
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
    wordcount \
    /user/hadoop/wordcount/input \
    /user/hadoop/wordcount/output
```
> ⚠️ The **output directory must NOT already exist**. If you re-run, either delete it (`hdfs dfs -rm -r .../output`) or use a new name.

### Step 3 — View the result
```bash
hdfs dfs -ls /user/hadoop/wordcount/output
hdfs dfs -cat /user/hadoop/wordcount/output/part-r-00000
```
Expected:
```
bird    3
cat     4
dog     3
fish    1
```
🎉 That was a full MapReduce job running through YARN. Watch it in the ResourceManager UI (http://localhost:8088) while it runs.

---

## 13. MapReduce practical — write your OWN WordCount in Java

Now write and compile the classic job yourself so you understand Mapper/Reducer.

### Step 1 — Create the source file
```bash
mkdir -p ~/wc_java && cd ~/wc_java
nano WordCount.java
```
Paste:
```java
import java.io.IOException;
import java.util.StringTokenizer;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class WordCount {

  // MAPPER: input (lineNumber, lineText) -> output (word, 1)
  public static class TokenizerMapper
       extends Mapper<Object, Text, Text, IntWritable> {
    private final static IntWritable one = new IntWritable(1);
    private Text word = new Text();

    public void map(Object key, Text value, Context context)
        throws IOException, InterruptedException {
      StringTokenizer itr = new StringTokenizer(value.toString());
      while (itr.hasMoreTokens()) {
        word.set(itr.nextToken());
        context.write(word, one);      // emit (word, 1)
      }
    }
  }

  // REDUCER: input (word, [1,1,1...]) -> output (word, total)
  public static class IntSumReducer
       extends Reducer<Text, IntWritable, Text, IntWritable> {
    private IntWritable result = new IntWritable();

    public void reduce(Text key, Iterable<IntWritable> values, Context context)
        throws IOException, InterruptedException {
      int sum = 0;
      for (IntWritable val : values) sum += val.get();
      result.set(sum);
      context.write(key, result);      // emit (word, count)
    }
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();
    Job job = Job.getInstance(conf, "word count");
    job.setJarByClass(WordCount.class);
    job.setMapperClass(TokenizerMapper.class);
    job.setCombinerClass(IntSumReducer.class);   // combiner = local reduce (optimization)
    job.setReducerClass(IntSumReducer.class);
    job.setOutputKeyClass(Text.class);
    job.setOutputValueClass(IntWritable.class);
    FileInputFormat.addInputPath(job, new Path(args[0]));
    FileOutputFormat.setOutputPath(job, new Path(args[1]));
    System.exit(job.waitForCompletion(true) ? 0 : 1);
  }
}
```

### Step 2 — Compile against Hadoop's classpath and build a jar
```bash
# Compile
javac -classpath $(hadoop classpath) -d . WordCount.java
# Package into a jar
jar -cvf wordcount.jar *.class
```

### Step 3 — Run your jar
```bash
# reuse the input from practical 12; output dir must be new
hadoop jar wordcount.jar WordCount \
    /user/hadoop/wordcount/input \
    /user/hadoop/wordcount/output_java

hdfs dfs -cat /user/hadoop/wordcount/output_java/part-r-00000
```
Same counts — but now it's **your** code. Try removing `setCombinerClass` and re-running to see the job still work (just less efficiently).

---

## 14. MapReduce practical — Hadoop Streaming with Python

**Hadoop Streaming** lets you write map/reduce in **any language** that reads stdin and writes stdout — great if you don't know Java.

### Step 1 — mapper.py
```bash
mkdir -p ~/wc_py && cd ~/wc_py
nano mapper.py
```
```python
#!/usr/bin/env python3
import sys
for line in sys.stdin:
    for word in line.strip().split():
        print(f"{word}\t1")     # emit  word <tab> 1
```

### Step 2 — reducer.py
```bash
nano reducer.py
```
```python
#!/usr/bin/env python3
import sys
current_word = None
current_count = 0
for line in sys.stdin:
    word, count = line.strip().split("\t", 1)
    count = int(count)
    if word == current_word:
        current_count += count
    else:
        if current_word is not None:
            print(f"{current_word}\t{current_count}")
        current_word = word
        current_count = count
if current_word is not None:
    print(f"{current_word}\t{current_count}")
```
> Note: Streaming guarantees input to the reducer is **sorted by key**, which is why this "detect key change" logic works.

### Step 3 — Make them executable and run
```bash
chmod +x mapper.py reducer.py

hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -input  /user/hadoop/wordcount/input \
    -output /user/hadoop/wordcount/output_py \
    -mapper  mapper.py \
    -reducer reducer.py \
    -file mapper.py -file reducer.py

hdfs dfs -cat /user/hadoop/wordcount/output_py/part-00000
```

---

## 15. Hive practical — SQL on Hadoop

**Hive** lets you query HDFS data with SQL-like **HiveQL**. Under the hood it runs MapReduce/Tez/Spark jobs.

### Install (brief)
```bash
wget https://downloads.apache.org/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz
tar -xzf apache-hive-3.1.3-bin.tar.gz && mv apache-hive-3.1.3-bin ~/hive
# add to ~/.bashrc:
echo 'export HIVE_HOME=/home/hadoop/hive'   >> ~/.bashrc
echo 'export PATH=$PATH:$HIVE_HOME/bin'     >> ~/.bashrc
source ~/.bashrc
# create warehouse dirs in HDFS
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod g+w /user/hive/warehouse
# initialize the metastore (stores table definitions)
schematool -dbType derby -initSchema
```

### Use it — start the Hive shell and run SQL
```bash
hive
```
```sql
-- Create a database and table
CREATE DATABASE mydb;
USE mydb;

CREATE TABLE students (
    id   INT,
    name STRING,
    marks INT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';

-- Load data from a local CSV (make students.csv: 1,Amit,85 etc.)
LOAD DATA LOCAL INPATH '/home/hadoop/students.csv' INTO TABLE students;

-- Query it with SQL — Hive turns this into a Hadoop job
SELECT * FROM students;
SELECT AVG(marks) FROM students;
SELECT name FROM students WHERE marks > 80 ORDER BY marks DESC;
```
Key point: you wrote **SQL**, Hive ran a **distributed job**. This is why Hive is the most-used Hadoop tool for analysts.

---

## 16. Pig practical — dataflow scripting

**Pig** uses **Pig Latin**, a scripting language for ETL/data transformation. Good when logic is a pipeline of steps rather than a single query.

### Run in local mode (quick test) or mapreduce mode
```bash
# after installing Pig and adding it to PATH:
pig -x local        # local mode for testing
# or:  pig           # runs on the Hadoop cluster
```

### Example script (word count in Pig — notice how short it is)
```pig
lines    = LOAD '/user/hadoop/wordcount/input' AS (line:chararray);
words    = FOREACH lines GENERATE FLATTEN(TOKENIZE(line)) AS word;
grouped  = GROUP words BY word;
counts   = FOREACH grouped GENERATE group AS word, COUNT(words) AS cnt;
ordered  = ORDER counts BY cnt DESC;
DUMP ordered;                        -- print to screen
-- STORE ordered INTO '/user/hadoop/pig_output';   -- or save to HDFS
```

---

## 17. Sqoop practical — import/export with databases

**Sqoop** moves data between **relational databases (MySQL, etc.)** and Hadoop.

### Import a MySQL table INTO HDFS
```bash
sqoop import \
  --connect jdbc:mysql://localhost/companydb \
  --username root --password yourpass \
  --table employees \
  --target-dir /user/hadoop/employees \
  --m 1                       # number of mappers (parallelism)
```

### Export FROM HDFS back into MySQL
```bash
sqoop export \
  --connect jdbc:mysql://localhost/companydb \
  --username root --password yourpass \
  --table employees_copy \
  --export-dir /user/hadoop/employees
```
Use case: pull operational data out of a database, analyze it in Hadoop/Hive, push results back.

---

## 18. HBase practical — NoSQL on Hadoop

**HBase** is a distributed, column-oriented NoSQL database on top of HDFS. Unlike HDFS (write-once, batch), HBase gives **real-time random read/write** access to individual rows.

### Start HBase and open its shell
```bash
start-hbase.sh
hbase shell
```
```
# Create a table 'emp' with column families 'personal' and 'professional'
create 'emp', 'personal', 'professional'

# Insert (put) values — row key 'row1'
put 'emp', 'row1', 'personal:name', 'Amit'
put 'emp', 'row1', 'personal:city', 'Delhi'
put 'emp', 'row1', 'professional:role', 'Engineer'

# Read a single row
get 'emp', 'row1'

# Scan the whole table
scan 'emp'

# Update = just put again with a new value
put 'emp', 'row1', 'personal:city', 'Mumbai'

# Delete a cell / disable+drop a table
delete 'emp', 'row1', 'personal:city'
disable 'emp'
drop 'emp'
```
Terminology: **row key**, **column family**, **column qualifier**, **cell**, **version** (HBase keeps timestamped versions of a cell).

---

## 19. Spark practical — fast in-memory processing

**Apache Spark** is the modern successor to MapReduce — up to ~100× faster for many jobs because it keeps data **in memory** (RDDs/DataFrames) instead of writing to disk between steps. It runs on YARN and reads HDFS.

### Start PySpark (Python shell)
```bash
# after installing Spark and setting SPARK_HOME + PATH:
pyspark
```

### WordCount in Spark (compare how much shorter than MapReduce!)
```python
# Read text from HDFS
text = sc.textFile("/user/hadoop/wordcount/input")

counts = (text.flatMap(lambda line: line.split())   # split into words
              .map(lambda word: (word, 1))           # (word, 1)
              .reduceByKey(lambda a, b: a + b))       # sum by word

for word, count in counts.collect():
    print(word, count)

# Save to HDFS
counts.saveAsTextFile("/user/hadoop/spark_output")
```

### DataFrame / Spark SQL version
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("demo").getOrCreate()

df = spark.read.csv("/user/hadoop/students.csv",
                    header=False, inferSchema=True) \
          .toDF("id", "name", "marks")
df.show()
df.createOrReplaceTempView("students")
spark.sql("SELECT AVG(marks) FROM students").show()
```
The same idea as Hive, but faster and more flexible. Most new "big data" jobs today are written in Spark.

---
---

# PART D — REFERENCE

## 20. Common errors & fixes

| Problem | Likely cause | Fix |
|---------|--------------|-----|
| `ssh localhost` asks for password | Passwordless SSH not set up | Redo Scenario 0, Step 4 (copy `id_rsa.pub` into `authorized_keys`) |
| `JAVA_HOME is not set and could not be found` | JAVA_HOME missing in `hadoop-env.sh` | Set it explicitly in `$HADOOP_HOME/etc/hadoop/hadoop-env.sh` |
| DataNode not in `jps` after start | Namespace ID mismatch (usually from re-formatting the NameNode) | Delete the datanode data dir contents, re-run, don't re-format a live cluster |
| `Output directory already exists` | MapReduce won't overwrite output | `hdfs dfs -rm -r <output>` or use a new output path |
| `Connection refused` to `localhost:9000` | NameNode not running / not formatted | Check `jps`; run `hdfs namenode -format` (first time only), then `start-dfs.sh` |
| Web UI at :50070 doesn't load | You're on Hadoop 3.x | Use port **9870** (2.x used 50070) |
| Safe mode: `Name node is in safe mode` | NameNode still checking blocks at startup | Wait, or force off: `hdfs dfsadmin -safemode leave` |
| Jobs stuck at ACCEPTED in YARN | Not enough memory allocated to NodeManager | Increase `yarn.nodemanager.resource.memory-mb` in `yarn-site.xml` |

**Where to look when something fails:** the logs. `$HADOOP_HOME/logs/` has a `.log` file per daemon (e.g. `hadoop-hadoop-namenode-*.log`). Read the last lines: `tail -n 50 $HADOOP_HOME/logs/hadoop-*-namenode-*.log`.

---

## 21. Interview quick-revision sheet

**Concepts**
- **Hadoop = HDFS (storage) + YARN (resources) + MapReduce (processing).**
- **Default block size:** 128 MB (Hadoop 2.x/3.x); 64 MB in 1.x.
- **Default replication factor:** 3.
- **NameNode** stores metadata (fsimage + edits); **DataNode** stores actual blocks.
- **Secondary NameNode** does checkpointing — it is **NOT** a backup/failover. HA uses a **Standby NameNode**.
- **Heartbeat**: DataNode → NameNode every 3s to prove it's alive.
- **YARN daemons:** ResourceManager (master), NodeManager (per node), ApplicationMaster (per job), Container (resource bundle).
- **MapReduce flow:** InputSplit → Map → Combiner → Partitioner → Shuffle & Sort → Reduce → Output.
- **Combiner** = local mini-reducer to cut network traffic (optional; must be commutative/associative).
- **Partitioner** decides which reducer a key goes to (default = hash % numReducers).
- **Data locality**: move computation to the data, not data to computation.
- **Rack awareness**: replica placement across racks for fault tolerance.
- **Hadoop 1 vs 2:** Hadoop 1 had JobTracker/TaskTracker and no YARN; Hadoop 2 introduced YARN, splitting resource management from processing.

**Modes:** Standalone (no daemons, local FS) → Pseudo-distributed (all daemons, 1 machine, HDFS) → Fully-distributed (multi-node).

**Ecosystem in one line each:** Hive = SQL; Pig = dataflow scripting; HBase = NoSQL random access; Sqoop = RDBMS↔Hadoop; Flume = log ingestion; Oozie = workflow scheduler; ZooKeeper = coordination; Spark = fast in-memory engine.

**Common ports (Hadoop 3.x):** NameNode UI 9870, DataNode UI 9864, Secondary NN 9868, ResourceManager UI 8088, NameNode RPC 9000/8020, JobHistory 19888.

---

## 22. Practice exercises (do these yourself)

Work through these to lock in the skills. No solutions given on purpose — struggle a little.

**HDFS**
1. Create the HDFS path `/practice/day1`, upload three local text files into it, list them recursively, then download one back and delete the rest.
2. Upload a file, set its replication factor to 2, then use `hdfs fsck` to confirm how many replicas exist and on which nodes.
3. Use `hdfs dfsadmin -report` to find how much total and remaining space your cluster has.

**MapReduce**
4. Modify the Java WordCount so it converts every word to lowercase before counting (hint: `value.toString().toLowerCase()`).
5. Modify it again to **ignore** words shorter than 3 letters.
6. Write a MapReduce (Java or Python streaming) that, given lines of `name,department,salary`, outputs the **average salary per department**. (Careful: average is not combiner-safe unless you also track counts.)

**Hive**
7. Create a Hive table for a CSV of `orders(order_id, customer, amount, city)`. Write queries for: total revenue per city; the top 3 customers by total amount; count of orders per city having more than 5 orders (`GROUP BY ... HAVING`).

**Spark**
8. Redo exercise 6 in PySpark using `reduceByKey`, then again using a DataFrame + `groupBy().avg()`. Compare which was easier.

**Concept**
9. Explain in your own words: why is the Secondary NameNode not a backup? What actually provides NameNode fault tolerance in production?
10. A 1 GB file is stored with the default block size and replication factor. How many blocks are created, and how much total disk does it consume across the cluster? (Answer: 8 blocks × 3 replicas = 24 block-copies; ~3 GB total.)

---

## Learning path summary (what to do, in order)

1. Read Part A until HDFS, YARN, and MapReduce make sense conceptually.
2. Do Scenario 0 + Scenario 1 (standalone) — get *something* running.
3. Do Scenario 2 (pseudo-distributed) — this is your main practice cluster.
4. Do practicals 11–14 (HDFS + all three WordCount styles). This is 80% of what freshers are tested on.
5. Add Hive (15) and Spark (19) — the two most job-relevant tools today.
6. Skim Sqoop, Pig, HBase so you can speak about them.
7. Do the Part D exercises and revise the interview sheet.
8. Only attempt Scenario 3 (multi-node) once single-node feels comfortable.

*Good luck — the fastest way to learn Hadoop is to break your pseudo-distributed cluster a few times and fix it.*
