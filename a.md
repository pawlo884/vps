PLAY [web] **************************************************************************************************
TASK [Gathering Facts] **************************************************************************************ok: [vps]

TASK [Print basic facts] ************************************************************************************ok: [vps] => 
  msg:
    cpu_vcpus: 6
    distro: Ubuntu 24.04
    hostname: daktylowy
    kernel: 6.8.0-87-generic
    memory_mb: 31937

TASK [Run audit commands] ***********************************************************************************ok: [vps] => (item=system_info)
ok: [vps] => (item=userspace)
ok: [vps] => (item=packages)
ok: [vps] => (item=services)
ok: [vps] => (item=binaries)
ok: [vps] => (item=firewall)
ok: [vps] => (item=networking)

TASK [Show audit outputs] ***********************************************************************************ok: [vps] => 
  audit_cmd_out.results:
  - ansible_loop_var: item
    changed: false
    cmd: |-
      echo "== uname =="; uname -a
      echo "== lsb_release =="; (lsb_release -a 2>/dev/null || cat /etc/os-release)
      echo "== uptime =="; uptime
    delta: '0:00:00.011942'
    end: '2025-11-03 09:33:06.748619'
    failed: false
    invocation:
      module_args:
        _raw_params: |-
          echo "== uname =="; uname -a
          echo "== lsb_release =="; (lsb_release -a 2>/dev/null || cat /etc/os-release)
          echo "== uptime =="; uptime
        _uses_shell: true
        argv: null
        chdir: null
        cmd: null
        creates: null
        executable: null
        expand_argument_vars: true
        removes: null
        stdin: null
        stdin_add_newline: true
        strip_empty_ends: true
    item:
      cmd: |-
        echo "== uname =="; uname -a
        echo "== lsb_release =="; (lsb_release -a 2>/dev/null || cat /etc/os-release)
        echo "== uptime =="; uptime
      name: system_info
    msg: ''
    rc: 0
    start: '2025-11-03 09:33:06.736677'
    stderr: ''
    stderr_lines: []
    stdout: |-
      == uname ==
      Linux daktylowy 6.8.0-87-generic #88-Ubuntu SMP PREEMPT_DYNAMIC Sat Oct 11 09:28:41 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux
      == lsb_release ==
      Distributor ID: Ubuntu
      Description:    Ubuntu 24.04.3 LTS
      Release:        24.04
      Codename:       noble
      == uptime ==
       09:33:06 up 22:49,  6 users,  load average: 0,16, 0,11, 0,09
    stdout_lines:
    - == uname ==
    - 'Linux daktylowy 6.8.0-87-generic #88-Ubuntu SMP PREEMPT_DYNAMIC Sat Oct 11 09:28:41 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux'
    - == lsb_release ==
    - "Distributor ID:\tUbuntu"
    - "Description:\tUbuntu 24.04.3 LTS"
    - "Release:\t24.04"
    - "Codename:\tnoble"
    - == uptime ==
    - ' 09:33:06 up 22:49,  6 users,  load average: 0,16, 0,11, 0,09'
  - ansible_loop_var: item
    changed: false
    cmd: |-
      echo "== whoami =="; whoami
      echo "== id =="; id
      echo "== sudo version =="; (sudo --version | head -1)
    delta: '0:00:00.007997'
    end: '2025-11-03 09:33:07.109776'
    failed: false
    invocation:
      module_args:
        _raw_params: |-
          echo "== whoami =="; whoami
          echo "== id =="; id
          echo "== sudo version =="; (sudo --version | head -1)
        _uses_shell: true
        argv: null
        chdir: null
        cmd: null
        creates: null
        executable: null
        expand_argument_vars: true
        removes: null
        stdin: null
        stdin_add_newline: true
        strip_empty_ends: true
    item:
      cmd: |-
        echo "== whoami =="; whoami
        echo "== id =="; id
        echo "== sudo version =="; (sudo --version | head -1)
      name: userspace
    msg: ''
    rc: 0
    start: '2025-11-03 09:33:07.101779'
    stderr: ''
    stderr_lines: []
    stdout: |-
      == whoami ==
      root
      == id ==
      uid=0(root) gid=0(root) groups=0(root)
      == sudo version ==
      Sudo version 1.9.15p5
    stdout_lines:
    - == whoami ==
    - root
    - == id ==
    - uid=0(root) gid=0(root) groups=0(root)
    - == sudo version ==
    - Sudo version 1.9.15p5
  - ansible_loop_var: item
    changed: false
    cmd: |-
      echo "== key packages ==";
      dpkg -l | egrep 'nginx|postgresql-client|ufw|fail2ban|docker|docker.io|docker-ce' || true
    delta: '0:00:00.012737'
    end: '2025-11-03 09:33:07.463370'
    failed: false
    invocation:
      module_args:
        _raw_params: |-
          echo "== key packages ==";
          dpkg -l | egrep 'nginx|postgresql-client|ufw|fail2ban|docker|docker.io|docker-ce' || true
        _uses_shell: true
        argv: null
        chdir: null
        cmd: null
        creates: null
        executable: null
        expand_argument_vars: true
        removes: null
        stdin: null
        stdin_add_newline: true
        strip_empty_ends: true
    item:
      cmd: |-
        echo "== key packages ==";
        dpkg -l | egrep 'nginx|postgresql-client|ufw|fail2ban|docker|docker.io|docker-ce' || true
      name: packages
    msg: ''
    rc: 0
    start: '2025-11-03 09:33:07.450633'
    stderr: ''
    stderr_lines: []
    stdout: |-
      == key packages ==
      ii  docker-buildx-plugin                 0.29.1-1~ubuntu.24.04~noble             amd64        Docker Buildx plugin extends build capabilities with BuildKit.
      ii  docker-ce                            5:28.5.1-1~ubuntu.24.04~noble           amd64        Docker: the open-source application container engine
      ii  docker-ce-cli                        5:28.5.1-1~ubuntu.24.04~noble           amd64        Docker CLI: the open-source application container engine
      ii  docker-ce-rootless-extras            5:28.5.1-1~ubuntu.24.04~noble           amd64        Rootless 
support for Docker.
      ii  docker-compose-plugin                2.40.3-1~ubuntu.24.04~noble             amd64        Docker Compose (V2) plugin for the Docker CLI.
      ii  fail2ban                             1.0.2-3ubuntu0.1                        all          ban hosts that cause multiple authentication errors
      ii  nginx                                1.24.0-2ubuntu7.5                       amd64        small, powerful, scalable web/proxy server
      ii  nginx-common                         1.24.0-2ubuntu7.5                       all          small, powerful, scalable web/proxy server - common files
      ii  ufw                                  0.36.2-6                                all          program for managing a Netfilter firewall
    stdout_lines:
    - == key packages ==
    - ii  docker-buildx-plugin                 0.29.1-1~ubuntu.24.04~noble             amd64        Docker Buildx plugin extends build capabilities with BuildKit.
    - 'ii  docker-ce                            5:28.5.1-1~ubuntu.24.04~noble           amd64        Docker: 
the open-source application container engine'
    - 'ii  docker-ce-cli                        5:28.5.1-1~ubuntu.24.04~noble           amd64        Docker CLI: the open-source application container engine'
    - ii  docker-ce-rootless-extras            5:28.5.1-1~ubuntu.24.04~noble           amd64        Rootless 
support for Docker.
    - ii  docker-compose-plugin                2.40.3-1~ubuntu.24.04~noble             amd64        Docker Compose (V2) plugin for the Docker CLI.
    - ii  fail2ban                             1.0.2-3ubuntu0.1                        all          ban hosts that cause multiple authentication errors
    - ii  nginx                                1.24.0-2ubuntu7.5                       amd64        small, powerful, scalable web/proxy server
    - ii  nginx-common                         1.24.0-2ubuntu7.5                       all          small, powerful, scalable web/proxy server - common files
    - ii  ufw                                  0.36.2-6                                all          program for managing a Netfilter firewall
  - ansible_loop_var: item
    changed: false
    cmd: |-
      echo "== services ==";
      systemctl is-active nginx || echo 'nginx: inactive'
      systemctl is-enabled nginx || echo 'nginx: not-enabled'
      systemctl is-active docker || echo 'docker: inactive'
      systemctl is-enabled docker || echo 'docker: not-enabled'
    delta: '0:00:00.019236'
    end: '2025-11-03 09:33:07.860831'
    failed: false
    invocation:
      module_args:
        _raw_params: |-
          echo "== services ==";
          systemctl is-active nginx || echo 'nginx: inactive'
          systemctl is-enabled nginx || echo 'nginx: not-enabled'
          systemctl is-active docker || echo 'docker: inactive'
          systemctl is-enabled docker || echo 'docker: not-enabled'
        _uses_shell: true
        argv: null
        chdir: null
        cmd: null
        creates: null
        executable: null
        expand_argument_vars: true
        removes: null
        stdin: null
        stdin_add_newline: true
        strip_empty_ends: true
    item:
      cmd: |-
        echo "== services ==";
        systemctl is-active nginx || echo 'nginx: inactive'
        systemctl is-enabled nginx || echo 'nginx: not-enabled'
        systemctl is-active docker || echo 'docker: inactive'
        systemctl is-enabled docker || echo 'docker: not-enabled'
      name: services
    msg: ''
    rc: 0
    start: '2025-11-03 09:33:07.841595'
    stderr: ''
    stderr_lines: []
    stdout: |-
      == services ==
      active
      enabled
      active
      enabled
    stdout_lines:
    - == services ==
    - active
    - enabled
    - active
    - enabled
  - ansible_loop_var: item
    changed: false
    cmd: |-
      echo "== versions ==";
      (nginx -v 2>&1 || echo 'nginx: missing')
      (psql --version 2>&1 || echo 'psql: missing')
      (docker --version 2>&1 || echo 'docker: missing')
      python3 --version
    delta: '0:00:00.018575'
    end: '2025-11-03 09:33:08.243662'
    failed: false
    invocation:
      module_args:
        _raw_params: |-
          echo "== versions ==";
          (nginx -v 2>&1 || echo 'nginx: missing')
          (psql --version 2>&1 || echo 'psql: missing')
          (docker --version 2>&1 || echo 'docker: missing')
          python3 --version
        _uses_shell: true
        argv: null
        chdir: null
        cmd: null
        creates: null
        executable: null
        expand_argument_vars: true
        removes: null
        stdin: null
        stdin_add_newline: true
        strip_empty_ends: true
    item:
      cmd: |-
        echo "== versions ==";
        (nginx -v 2>&1 || echo 'nginx: missing')
        (psql --version 2>&1 || echo 'psql: missing')
        (docker --version 2>&1 || echo 'docker: missing')
        python3 --version
      name: binaries
    msg: ''
    rc: 0
    start: '2025-11-03 09:33:08.225087'
    stderr: ''
    stderr_lines: []
    stdout: |-
      == versions ==
      nginx version: nginx/1.24.0 (Ubuntu)
      /bin/sh: 3: psql: not found
      psql: missing
      Docker version 28.5.1, build e180ab8
      Python 3.12.3
    stdout_lines:
    - == versions ==
    - 'nginx version: nginx/1.24.0 (Ubuntu)'
    - '/bin/sh: 3: psql: not found'
    - 'psql: missing'
    - Docker version 28.5.1, build e180ab8
    - Python 3.12.3
  - ansible_loop_var: item
    changed: false
    cmd: |-
      echo "== ufw ==";
      ufw status || true
    delta: '0:00:00.060623'
    end: '2025-11-03 09:33:08.663781'
    failed: false
    invocation:
      module_args:
        _raw_params: |-
          echo "== ufw ==";
          ufw status || true
        _uses_shell: true
        argv: null
        chdir: null
        cmd: null
        creates: null
        executable: null
        expand_argument_vars: true
        removes: null
        stdin: null
        stdin_add_newline: true
        strip_empty_ends: true
    item:
      cmd: |-
        echo "== ufw ==";
        ufw status || true
      name: firewall
    msg: ''
    rc: 0
    start: '2025-11-03 09:33:08.603158'
    stderr: ''
    stderr_lines: []
    stdout: |-
      == ufw ==
      Status: active
  
      To                         Action      From
      --                         ------      ----
      22/tcp                     ALLOW       Anywhere
      80/tcp                     ALLOW       Anywhere
      443/tcp                    ALLOW       Anywhere
      22/tcp (v6)                ALLOW       Anywhere (v6)
      80/tcp (v6)                ALLOW       Anywhere (v6)
      443/tcp (v6)               ALLOW       Anywhere (v6)
    stdout_lines:
    - == ufw ==
    - 'Status: active'
    - ''
    - To                         Action      From
    - --                         ------      ----
    - '22/tcp                     ALLOW       Anywhere                  '
    - '80/tcp                     ALLOW       Anywhere                  '
    - '443/tcp                    ALLOW       Anywhere                  '
    - '22/tcp (v6)                ALLOW       Anywhere (v6)             '
    - '80/tcp (v6)                ALLOW       Anywhere (v6)             '
    - '443/tcp (v6)               ALLOW       Anywhere (v6)             '
  - ansible_loop_var: item
    changed: false
    cmd: |-
      echo "== listening ports ==";
      ss -tulpen | head -n 50
    delta: '0:00:00.045147'
    end: '2025-11-03 09:33:09.075258'
    failed: false
    invocation:
      module_args:
        _raw_params: |-
          echo "== listening ports ==";
          ss -tulpen | head -n 50
        _uses_shell: true
        argv: null
        chdir: null
        cmd: null
        creates: null
        executable: null
        expand_argument_vars: true
        removes: null
        stdin: null
        stdin_add_newline: true
        strip_empty_ends: true
    item:
      cmd: |-
        echo "== listening ports ==";
        ss -tulpen | head -n 50
      name: networking
    msg: ''
    rc: 0
    start: '2025-11-03 09:33:09.030111'
    stderr: ''
    stderr_lines: []
    stdout: |-
      == listening ports ==
      Netid State  Recv-Q Send-Q        Local Address:Port  Peer Address:PortProcess
      udp   UNCONN 0      0                127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=8895,fd=16)) uid:992 ino:67177 sk:1 cgroup:/system.slice/systemd-resolved.service <->
      udp   UNCONN 0      0             127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=8895,fd=14)) uid:992 ino:67175 sk:2 cgroup:/system.slice/systemd-resolved.service <->
      udp   UNCONN 0      0      192.168.50.31%enp1s0:68         0.0.0.0:*    users:(("systemd-network",pid=8522,fd=23)) uid:998 ino:493577 sk:3 cgroup:/system.slice/systemd-networkd.service <->
      tcp   LISTEN 0      4096                0.0.0.0:9000       0.0.0.0:*    users:(("docker-proxy",pid=24706,fd=7)) ino:144493 sk:4 cgroup:/system.slice/docker.service <->
      tcp   LISTEN 0      4096             127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=8895,fd=17)) uid:992 ino:67178 sk:5 cgroup:/system.slice/systemd-resolved.service <->
      tcp   LISTEN 0      4096          127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=8895,fd=15)) uid:992 ino:67176 sk:6 cgroup:/system.slice/systemd-resolved.service <->
      tcp   LISTEN 0      511               127.0.0.1:38419      0.0.0.0:*    users:(("node",pid=66291,fd=19)) uid:1000 ino:496235 sk:7 cgroup:/user.slice/user-1000.slice/session-161.scope <->
      tcp   LISTEN 0      4096                0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=14053,fd=3),("systemd",pid=1,fd=148)) ino:13146 sk:8 cgroup:/system.slice/ssh.socket <->
      tcp   LISTEN 0      511                 0.0.0.0:80         0.0.0.0:*    users:(("nginx",pid=16077,fd=5),("nginx",pid=16076,fd=5),("nginx",pid=16075,fd=5),("nginx",pid=16074,fd=5),("nginx",pid=16073,fd=5),("nginx",pid=16072,fd=5),("nginx",pid=16069,fd=5)) ino:84224 sk:9 cgroup:/system.slice/nginx.service <->
      tcp   LISTEN 0      511               127.0.0.1:41755      0.0.0.0:*    users:(("node",pid=66327,fd=19)) uid:1000 ino:498257 sk:a cgroup:/user.slice/user-1000.slice/session-161.scope <->
      tcp   LISTEN 0      4096                   [::]:9000          [::]:*    users:(("docker-proxy",pid=24713,fd=7)) ino:144494 sk:b cgroup:/system.slice/docker.service v6only:1 <->
      tcp   LISTEN 0      4096                   [::]:22            [::]:*    users:(("sshd",pid=14053,fd=4),("systemd",pid=1,fd=149)) ino:15251 sk:c cgroup:/system.slice/ssh.socket v6only:1 <->
      tcp   LISTEN 0      511                    [::]:80            [::]:*    users:(("nginx",pid=16077,fd=6),("nginx",pid=16076,fd=6),("nginx",pid=16075,fd=6),("nginx",pid=16074,fd=6),("nginx",pid=16073,fd=6),("nginx",pid=16072,fd=6),("nginx",pid=16069,fd=6)) ino:84225 sk:d cgroup:/system.slice/nginx.service v6only:1 <->    
    stdout_lines:
    - == listening ports ==
    - 'Netid State  Recv-Q Send-Q        Local Address:Port  Peer Address:PortProcess

                                                                                                 '
    - 'udp   UNCONN 0      0                127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=8895,fd=16)) uid:992 ino:67177 sk:1 cgroup:/system.slice/systemd-resolved.service <->
                                                                                                 '
    - 'udp   UNCONN 0      0             127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=8895,fd=14)) uid:992 ino:67175 sk:2 cgroup:/system.slice/systemd-resolved.service <->
                                                                                                 '
    - 'udp   UNCONN 0      0      192.168.50.31%enp1s0:68         0.0.0.0:*    users:(("systemd-network",pid=8522,fd=23)) uid:998 ino:493577 sk:3 cgroup:/system.slice/systemd-networkd.service <->
                                                                                                 '
    - 'tcp   LISTEN 0      4096                0.0.0.0:9000       0.0.0.0:*    users:(("docker-proxy",pid=24706,fd=7)) ino:144493 sk:4 cgroup:/system.slice/docker.service <->
                                                                                                 '
    - 'tcp   LISTEN 0      4096             127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=8895,fd=17)) uid:992 ino:67178 sk:5 cgroup:/system.slice/systemd-resolved.service <->
                                                                                                 '
    - 'tcp   LISTEN 0      4096          127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=8895,fd=15)) uid:992 ino:67176 sk:6 cgroup:/system.slice/systemd-resolved.service <->
                                                                                                 '
    - 'tcp   LISTEN 0      511               127.0.0.1:38419      0.0.0.0:*    users:(("node",pid=66291,fd=19)) uid:1000 ino:496235 sk:7 cgroup:/user.slice/user-1000.slice/session-161.scope <->
                                                                                                 '
    - 'tcp   LISTEN 0      4096                0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=14053,fd=3),("systemd",pid=1,fd=148)) ino:13146 sk:8 cgroup:/system.slice/ssh.socket <->
                                                                                                 '
    - tcp   LISTEN 0      511                 0.0.0.0:80         0.0.0.0:*    users:(("nginx",pid=16077,fd=5),("nginx",pid=16076,fd=5),("nginx",pid=16075,fd=5),("nginx",pid=16074,fd=5),("nginx",pid=16073,fd=5),("nginx",pid=16072,fd=5),("nginx",pid=16069,fd=5)) ino:84224 sk:9 cgroup:/system.slice/nginx.service <->
    - 'tcp   LISTEN 0      511               127.0.0.1:41755      0.0.0.0:*    users:(("node",pid=66327,fd=19)) uid:1000 ino:498257 sk:a cgroup:/user.slice/user-1000.slice/session-161.scope <->
                                                                                                 '
    - 'tcp   LISTEN 0      4096                   [::]:9000          [::]:*    users:(("docker-proxy",pid=24713,fd=7)) ino:144494 sk:b cgroup:/system.slice/docker.service v6only:1 <->
                                                                                                 '
    - 'tcp   LISTEN 0      4096                   [::]:22            [::]:*    users:(("sshd",pid=14053,fd=4),("systemd",pid=1,fd=149)) ino:15251 sk:c cgroup:/system.slice/ssh.socket v6only:1 <->
                                                                                                 '
    - tcp   LISTEN 0      511                    [::]:80            [::]:*    users:(("nginx",pid=16077,fd=6),("nginx",pid=16076,fd=6),("nginx",pid=16075,fd=6),("nginx",pid=16074,fd=6),("nginx",pid=16073,fd=6),("nginx",pid=16072,fd=6),("nginx",pid=16069,fd=6)) ino:84225 sk:d cgroup:/system.slice/nginx.service v6only:1 <->    

PLAY RECAP **************************************************************************************************vps                        : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0