# Fixing a Hadoop MapReduce Job That Wouldn't Run

**Environment:** Single-node Hadoop 3.3.6 on an Azure Ubuntu VM (`ubuntuhadoop1`), Java 17, running the built-in `wordcount` example.

**Goal:** Run a MapReduce word-count job over trip data placed in HDFS.

This document records every problem hit during the session and the exact fix applied, in the order they occurred. Each step also explains *why* it happened so the reasoning transfers to other setups.

---

## Summary table

| # | Symptom | Root cause | Fix |
|---|---------|-----------|-----|
| 1 | `cd /smartride/...` → "No such file or directory" | Path is in HDFS, not local disk | Use `hdfs dfs` commands, not `cd`/`ls` |
| 2 | `WARN NativeCodeLoader` on every command | Optional native libs absent | Harmless — ignore |
| 3 | Job fails: container launch `ConnectionRefused` to `...internal.cloudapp.net` | RM/NM couldn't resolve each other's hostname | Add hostname to `/etc/hosts`; pin hostnames in `yarn-site.xml` |
| 4 | Client can't reach RM at `ubuntuhadoop1:8032` | RM answered only on loopback | Map `ubuntuhadoop1` → `127.0.0.1` in `/etc/hosts` |
| 5 | Container exits 1: `ClassNotFoundException: MRAppMaster` | `HADOOP_MAPRED_HOME` not set for containers | Add env + framework props to `mapred-site.xml` |
| 6 | Container exits 1: `InaccessibleObjectException ... does not "opens java.lang"` | Java 17 module encapsulation vs Hadoop 3.3.6 | Add `--add-opens` JVM flags in `mapred-site.xml` |
| ✅ | `Job completed successfully` | — | Read results from `part-r-00000` |

---

## Step 1 — Understanding HDFS vs the local filesystem

**Symptom**
```
cd /smartride/mapreduce/input
bash: cd: /smartride/mapreduce/input: No such file or directory
```

**Cause.** The directory existed in **HDFS** (Hadoop's distributed filesystem), which is a completely separate namespace from the local Linux disk. Shell commands like `cd`, `ls`, and `cat` only see the local disk, so they can never find an HDFS path.

**Fix.** Use `hdfs dfs` commands for anything inside HDFS. There is no `cd` in HDFS — you pass the full path every time.

```bash
# create the input folder in HDFS (-p builds the full path)
hdfs dfs -mkdir -p /smartride/mapreduce/input

# copy a local file INTO HDFS
hdfs dfs -put ~/smartride/smartride_trip_words.txt /smartride/mapreduce/input/

# list / view HDFS contents
hdfs dfs -ls  /smartride/mapreduce/input
hdfs dfs -cat /smartride/mapreduce/input/smartride_trip_words.txt
```

**Rule of thumb**

| Command | Sees local disk | Sees HDFS |
|---------|:---:|:---:|
| `ls`, `cd`, `cat`, `nano` | ✅ | ❌ |
| `hdfs dfs -ls`, `-cat`, `-put`, `-get` | ❌ | ✅ |

---

## Step 2 — The NativeCodeLoader warning (not an error)

**Symptom** — appears on almost every command:
```
WARN util.NativeCodeLoader: Unable to load native-hadoop library for your
platform... using builtin-java classes where applicable
```

**Cause.** Hadoop couldn't find its optional native (C-compiled) libraries and fell back to the built-in Java implementations.

**Fix.** None needed. This is a harmless warning; everything works normally. Safe to ignore throughout.

---

## Step 3 — Container launch fails: connection refused (YARN hostname mismatch)

**Symptom**
```
Job ... failed with state FAILED due to: Application ... failed 2 times due to
Error launching appattempt... Got exception: java.net.ConnectException:
Call From ubuntuhadoop1/10.0.0.11 to
ubuntuhadoop1.xb1h52kngcyu3m2mcywtu1dtgg.cx.internal.cloudapp.net:46177
failed on connection exception: Connection refused
```

All five daemons were running (`jps` showed NameNode, DataNode, SecondaryNameNode, ResourceManager, NodeManager), so nothing had crashed.

**Cause.** `hostname -f` returned a long Azure-internal FQDN (`...internal.cloudapp.net`) that had **no entry in `/etc/hosts`**. YARN's ResourceManager tried to reach the NodeManager using that unresolvable name, so the connection failed.

**Diagnosis commands**
```bash
hostname          # ubuntuhadoop1
hostname -f       # ubuntuhadoop1.xb1h52...cx.internal.cloudapp.net
cat /etc/hosts    # <- the FQDN was not listed
```

**Fix — part A: add the hostname to `/etc/hosts`**
```bash
sudo nano /etc/hosts
```
Add a line mapping the machine's IP to both the FQDN and the short name:
```
10.0.0.11   ubuntuhadoop1.xb1h52kngcyu3m2mcywtu1dtgg.cx.internal.cloudapp.net   ubuntuhadoop1
```

**Fix — part B: pin the hostnames in `yarn-site.xml`** so YARN stops using the Azure FQDN:
```xml
<property>
  <name>yarn.resourcemanager.hostname</name>
  <value>ubuntuhadoop1</value>
</property>
<property>
  <name>yarn.nodemanager.hostname</name>
  <value>ubuntuhadoop1</value>
</property>
<property>
  <name>yarn.nodemanager.address</name>
  <value>ubuntuhadoop1:0</value>
</property>
<property>
  <name>yarn.nodemanager.bind-host</name>
  <value>0.0.0.0</value>
</property>
<property>
  <name>yarn.resourcemanager.bind-host</name>
  <value>0.0.0.0</value>
</property>
```

Restart YARN after any `yarn-site.xml` change:
```bash
stop-yarn.sh && start-yarn.sh && jps
```

---

## Step 4 — Client can't reach the ResourceManager on the private IP

**Symptom** — after the hostname fix, the container-launch error disappeared, but the client now looped:
```
INFO ipc.Client: Retrying connect to server: ubuntuhadoop1/10.0.0.11:8032.
Already tried N time(s)...
```

**Cause.** The RM was listening (`ss` showed `*:8032`), but a direct connection test proved it only answered on **loopback**:
```bash
nc -zv 127.0.0.1   8032   # succeeded
nc -zv 10.0.0.11   8032   # Connection refused
nc -zv ubuntuhadoop1 8032 # Connection refused (resolves to 10.0.0.11)
```
On this Azure VM the RM effectively served only `127.0.0.1`, so any client using the private IP was refused. Explicit `0.0.0.0` service-address settings did not change this behaviour.

**Fix.** Since the RM reliably worked on loopback, make **every** Hadoop component resolve the hostname to loopback by editing `/etc/hosts`:
```
127.0.0.1   localhost   ubuntuhadoop1   ubuntuhadoop1.xb1h52kngcyu3m2mcywtu1dtgg.cx.internal.cloudapp.net
```
(The separate `10.0.0.11` line was removed so the name resolves to exactly one address.)

Because the hostname mapping changed, restart **both** HDFS and YARN:
```bash
stop-yarn.sh; stop-dfs.sh
start-dfs.sh; start-yarn.sh
jps
nc -zv ubuntuhadoop1 8032   # now: succeeded
```

> **Note:** Pointing the hostname at `127.0.0.1` is a pragmatic fix for a **single-node** lab VM. On a real multi-node cluster you would instead ensure the private IP is reachable and used consistently, not loopback.

---

## Step 5 — Container exits 1: MRAppMaster class not found

**Symptom**
```
Error: Could not find or load main class
org.apache.hadoop.mapreduce.v2.app.MRAppMaster
Caused by: java.lang.ClassNotFoundException: ...MRAppMaster
Please check whether your <HADOOP_HOME>/etc/hadoop/mapred-site.xml contains ...
```

**Cause.** The launched container did not have `HADOOP_MAPRED_HOME` set, so it couldn't locate the MapReduce jars. (The error message itself names the fix.)

**Fix.** Rewrite `mapred-site.xml` with the framework name and the environment pointing at the Hadoop install (`/opt/bigdata/hadoop`, a valid symlink to `hadoop-3.3.6`):
```xml
<property>
  <name>mapreduce.framework.name</name>
  <value>yarn</value>
</property>
<property>
  <name>yarn.app.mapreduce.am.env</name>
  <value>HADOOP_MAPRED_HOME=/opt/bigdata/hadoop</value>
</property>
<property>
  <name>mapreduce.map.env</name>
  <value>HADOOP_MAPRED_HOME=/opt/bigdata/hadoop</value>
</property>
<property>
  <name>mapreduce.reduce.env</name>
  <value>HADOOP_MAPRED_HOME=/opt/bigdata/hadoop</value>
</property>
```
`mapred-site.xml` is read at job submission, so no restart is needed — just re-run the job.

---

## Step 6 — Container exits 1: Java 17 module access (the real blocker)

**Symptom** — from the container's `syslog`:
```
ERROR MRAppMaster: Error starting MRAppMaster
java.lang.ExceptionInInitializerError
  ...
Caused by: java.lang.reflect.InaccessibleObjectException: Unable to make
protected final java.lang.Class java.lang.ClassLoader.defineClass(...)
accessible: module java.base does not "opens java.lang" to unnamed module
```

**Cause.** The VM ran **Java 17**, but Hadoop 3.3.6 was built for Java 8/11. Java's strong module encapsulation (introduced later) blocks the reflection that Hadoop's Guice-based web layer performs, crashing the AppMaster at startup. This was unrelated to all the earlier networking work — that had already been fixed correctly.

**How it was found.** Log aggregation was off, so `yarn logs` returned nothing. The real stack trace was read directly from disk:
```bash
find $HADOOP_HOME/logs/userlogs -path '*application_*' -name syslog
cat .../container_..._000001/syslog
```

**Fix.** Grant the required module access via JVM `--add-opens` flags on the MapReduce containers, in `mapred-site.xml`:
```xml
<property>
  <name>yarn.app.mapreduce.am.command-opts</name>
  <value>-Xmx1024m --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.net=ALL-UNNAMED --add-opens java.base/java.security=ALL-UNNAMED</value>
</property>
<property>
  <name>mapreduce.map.java.opts</name>
  <value>-Xmx1024m --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED</value>
</property>
<property>
  <name>mapreduce.reduce.java.opts</name>
  <value>-Xmx1024m --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED</value>
</property>
```

**Alternative (cleaner long-term) fix.** Install and point Hadoop at Java 8 or 11 via `JAVA_HOME` in `hadoop-env.sh`, then restart all daemons. The `--add-opens` approach was chosen here because it required no reinstall.

---

## Result — job completes

```
map   0% reduce   0%
map  50% reduce   0%
map 100% reduce   0%
map 100% reduce 100%
Job job_1783492639119_0003 completed successfully
```

Selected counters confirming a clean run:
- `Map input records = 43`
- `Map output records = 64`
- `Reduce output records = 46` (46 unique words)
- `Data-local map tasks = 2`

**Reading the output** — results are written into HDFS in the output folder:
```bash
hdfs dfs -ls  /smartride/mapreduce/output_builtin
#   _SUCCESS        <- marker only, empty
#   part-r-00000    <- the actual word counts

hdfs dfs -cat /smartride/mapreduce/output_builtin/part-r-00000
```

---

## Final working configuration files

### `/etc/hosts` (IPv4 portion)
```
127.0.0.1   localhost   ubuntuhadoop1   ubuntuhadoop1.xb1h52kngcyu3m2mcywtu1dtgg.cx.internal.cloudapp.net
```

### `yarn-site.xml` (inside `<configuration>`)
```xml
<property><name>yarn.resourcemanager.hostname</name><value>ubuntuhadoop1</value></property>
<property><name>yarn.nodemanager.hostname</name><value>ubuntuhadoop1</value></property>
<property><name>yarn.nodemanager.address</name><value>ubuntuhadoop1:0</value></property>
<property><name>yarn.nodemanager.bind-host</name><value>0.0.0.0</value></property>
<property><name>yarn.resourcemanager.bind-host</name><value>0.0.0.0</value></property>
<property><name>yarn.resourcemanager.address</name><value>0.0.0.0:8032</value></property>
<property><name>yarn.resourcemanager.scheduler.address</name><value>0.0.0.0:8030</value></property>
<property><name>yarn.resourcemanager.resource-tracker.address</name><value>0.0.0.0:8031</value></property>
<property><name>yarn.resourcemanager.admin.address</name><value>0.0.0.0:8033</value></property>
<property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
```

### `mapred-site.xml` (inside `<configuration>`)
```xml
<property><name>mapreduce.framework.name</name><value>yarn</value></property>
<property><name>yarn.app.mapreduce.am.env</name><value>HADOOP_MAPRED_HOME=/opt/bigdata/hadoop</value></property>
<property><name>mapreduce.map.env</name><value>HADOOP_MAPRED_HOME=/opt/bigdata/hadoop</value></property>
<property><name>mapreduce.reduce.env</name><value>HADOOP_MAPRED_HOME=/opt/bigdata/hadoop</value></property>
<property><name>yarn.app.mapreduce.am.command-opts</name><value>-Xmx1024m --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.net=ALL-UNNAMED --add-opens java.base/java.security=ALL-UNNAMED</value></property>
<property><name>mapreduce.map.java.opts</name><value>-Xmx1024m --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED</value></property>
<property><name>mapreduce.reduce.java.opts</name><value>-Xmx1024m --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED</value></property>
```

---

## Reusable checklist for next time

1. **Start services**, then confirm with `jps` (expect all 5 daemons).
2. **Put input into HDFS** with `hdfs dfs -mkdir -p` and `hdfs dfs -put`.
3. **Delete any old output folder** — Hadoop refuses to overwrite: `hdfs dfs -rm -r -f <output>`.
4. **Run the job.** If it fails, read the *container* log (`.../logs/userlogs/<appId>/<container>/syslog`) for the real cause — the console only shows a summary.
5. **View results** in `part-r-00000` inside the output folder.

Because the config fixes above are saved to disk, future jobs on this VM run without repeating steps 3–6 of the troubleshooting.
