pawlo@DESKTOP-07HFRPQ:~/vps/ansible$ ansible-playbook playbooks/site.yml -K -vvv 2>&1 | head -200
BECOME password: 
ansible-playbook [core 2.16.3]
  config file = /home/pawlo/vps/ansible/ansible.cfg
  configured module search path = ['/home/pawlo/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /home/pawlo/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible-playbook
  python version = 3.12.3 (main, Aug 14 2025, 17:47:21) [GCC 13.3.0] (/usr/bin/python3)
  jinja version = 3.1.2
  libyaml = True
Using /home/pawlo/vps/ansible/ansible.cfg as config file
host_list declined parsing /home/pawlo/vps/ansible/inventories/prod/hosts.ini as it did not pass its verify_file() method
auto declined parsing /home/pawlo/vps/ansible/inventories/prod/hosts.ini as it did not pass its verify_file() method
yaml declined parsing /home/pawlo/vps/ansible/inventories/prod/hosts.ini as it did not pass its verify_file() method
Parsed /home/pawlo/vps/ansible/inventories/prod/hosts.ini inventory source with ini plugin
redirecting (type: modules) ansible.builtin.ufw to community.general.ufw
redirecting (type: modules) ansible.builtin.ufw to community.general.ufw
redirecting (type: modules) ansible.builtin.ufw to community.general.ufw
redirecting (type: callback) ansible.builtin.yaml to community.general.yaml
redirecting (type: callback) ansible.builtin.yaml to community.general.yaml
Skipping callback 'default', as we already have a stdout callback.
Skipping callback 'minimal', as we already have a stdout callback.
Skipping callback 'oneline', as we already have a stdout callback.

PLAYBOOK: site.yml *************************************************************
1 plays in playbooks/site.yml

PLAY [web] *********************************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/pawlo/vps/ansible/playbooks/site.yml:1

<192.168.50.31> ESTABLISH SSH CONNECTION FOR USER: pawel
<192.168.50.31> SSH: EXEC ssh -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="pawel"' -o ConnectTimeout=10 -o 'ControlPath="/home/pawlo/.ansible/cp/f5e59464ca"' 192.168.50.31 '/bin/sh -c '"'"'echo ~pawel && sleep 0'"'"''
<192.168.50.31> (0, b'/home/pawel\n', b'')
<192.168.50.31> ESTABLISH SSH CONNECTION FOR USER: pawel
<192.168.50.31> SSH: EXEC ssh -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="pawel"' -o ConnectTimeout=10 -o 'ControlPath="/home/pawlo/.ansible/cp/f5e59464ca"' 192.168.50.31 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/pawel/.ansible/tmp `"&& mkdir "` echo /home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005 `" && echo ansible-tmp-1762250830.5767138-3007-82292079385005="` echo /home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005 `" ) && sleep 0'"'"''
<192.168.50.31> (0, b'ansible-tmp-1762250830.5767138-3007-82292079385005=/home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005\n', b'')<vps> Attempting python interpreter discovery
<192.168.50.31> ESTABLISH SSH CONNECTION FOR USER: pawel
<192.168.50.31> SSH: EXEC ssh -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="pawel"' -o ConnectTimeout=10 -o 'ControlPath="/home/pawlo/.ansible/cp/f5e59464ca"' 192.168.50.31 '/bin/sh -c '"'"'echo PLATFORM; uname; echo FOUND; command -v '"'"'"'"'"'"'"'"'python3.12'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.11'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.10'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.9'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.8'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.6'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python3'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/libexec/platform-python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python2.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python'"'"'"'"'"'"'"'"'; echo ENDFOUND && sleep 0'"'"''
<192.168.50.31> (0, b'PLATFORM\nLinux\nFOUND\n/usr/bin/python3.12\n/usr/bin/python3\nENDFOUND\n', b'')
<192.168.50.31> ESTABLISH SSH CONNECTION FOR USER: pawel
<192.168.50.31> SSH: EXEC ssh -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="pawel"' -o ConnectTimeout=10 -o 'ControlPath="/home/pawlo/.ansible/cp/f5e59464ca"' 192.168.50.31 '/bin/sh -c '"'"'/usr/bin/python3.12 && sleep 0'"'"''
<192.168.50.31> (0, b'{"platform_dist_result": [], "osrelease_content": "PRETTY_NAME=\\"Ubuntu 24.04.3 LTS\\"\\nNAME=\\"Ubuntu\\"\\nVERSION_ID=\\"24.04\\"\\nVERSION=\\"24.04.3 LTS (Noble Numbat)\\"\\nVERSION_CODENAME=noble\\nID=ubuntu\\nID_LIKE=debian\\nHOME_URL=\\"https://www.ubuntu.com/\\"\\nSUPPORT_URL=\\"https://help.ubuntu.com/\\"\\nBUG_REPORT_URL=\\"https://bugs.launchpad.net/ubuntu/\\"\\nPRIVACY_POLICY_URL=\\"https://www.ubuntu.com/legal/terms-and-policies/privacy-policy\\"\\nUBUNTU_CODENAME=noble\\nLOGO=ubuntu-logo\\n"}\n', b'')
Using module file /usr/lib/python3/dist-packages/ansible/modules/setup.py
<192.168.50.31> PUT /home/pawlo/.ansible/tmp/ansible-local-3001ivugb2rj/tmpyvo1lmga TO /home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005/AnsiballZ_setup.py
<192.168.50.31> SSH: EXEC sftp -b - -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="pawel"' -o ConnectTimeout=10 -o 'ControlPath="/home/pawlo/.ansible/cp/f5e59464ca"' '[192.168.50.31]'
<192.168.50.31> (0, b'sftp> put /home/pawlo/.ansible/tmp/ansible-local-3001ivugb2rj/tmpyvo1lmga /home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005/AnsiballZ_setup.py\n', b'')
<192.168.50.31> ESTABLISH SSH CONNECTION FOR USER: pawel
<192.168.50.31> SSH: EXEC ssh -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="pawel"' -o ConnectTimeout=10 -o 'ControlPath="/home/pawlo/.ansible/cp/f5e59464ca"' 192.168.50.31 '/bin/sh -c '"'"'chmod u+x /home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005/ /home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005/AnsiballZ_setup.py && sleep 0'"'"''
<192.168.50.31> (0, b'', b'')
<192.168.50.31> ESTABLISH SSH CONNECTION FOR USER: pawel
<192.168.50.31> SSH: EXEC ssh -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="pawel"' -o ConnectTimeout=10 -o 'ControlPath="/home/pawlo/.ansible/cp/f5e59464ca"' -tt 192.168.50.31 '/bin/sh -c '"'"'sudo -H -S -p "[sudo via ansible, key=dgxdoffikoehbxuduopndmabxvnyhwin] password:" -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-dgxdoffikoehbxuduopndmabxvnyhwin ; /usr/bin/python3 /home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation failed
<192.168.50.31> ESTABLISH SSH CONNECTION FOR USER: pawel
<192.168.50.31> SSH: EXEC ssh -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="pawel"' -o ConnectTimeout=10 -o 'ControlPath="/home/pawlo/.ansible/cp/f5e59464ca"' 192.168.50.31 '/bin/sh -c '"'"'rm -f -r /home/pawel/.ansible/tmp/ansible-tmp-1762250830.5767138-3007-82292079385005/ > /dev/null 2>&1 && sleep 0'"'"''
<192.168.50.31> (0, b'', b'')
fatal: [vps]: FAILED! =>
  msg: Incorrect sudo password

PLAY RECAP *********************************************************************
vps                        : ok=0    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0