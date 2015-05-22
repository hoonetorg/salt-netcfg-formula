netcfg_file__pkg_bridge-utils:
  pkg.installed:
    - name: bridge-utils
    - watch_in: 
      - service: netcfg_file__service_networkrunning
{% set slsrequires =salt['pillar.get']('netcfg:file:slsrequires', False) %}
{% if slsrequires is defined and slsrequires %}
    - require:
{% for slsrequire in slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}

{% set use_networkmanager = salt['pillar.get']('netcfg:file:system:use_networkmanager', True) %}

{% if use_networkmanager is defined and use_networkmanager %}
  {% set servicenetworkenabled = "NetworkManager" %}
{% else %}
  {% set servicenetworkenabled = "network" %}
  {% set servicenetworkdisabled = "NetworkManager" %}
{% endif %}

{% if servicenetworkdisabled is defined and servicenetworkdisabled != "" %}
netcfg_file__service_networkdisabled:
  service.disabled:
    - name: {{servicenetworkdisabled}}
    - watch_in: 
      - service: netcfg_file__service_networkrunning
    - require:
      - pkg: netcfg_file__pkg_bridge-utils
netcfg_file__service_networkdead:
  service.dead:
    - name: {{servicenetworkdisabled}}
    - watch_in: 
      - service: netcfg_file__service_networkrunning
    - require:
      - pkg: netcfg_file__pkg_bridge-utils
{% endif %}


{% set resolv_conf = salt['pillar.get']('netcfg:file:resolv_conf', {}) %}
{% if resolv_conf.dns is defined and resolv_conf.dns != "" %}
netcfg_file__file_/etc/resolv.conf:
  file.managed:
    - name: /etc/resolv.conf
    - source: salt://netcfg/file/resolv.conf.jinja
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: netcfg_file__pkg_bridge-utils
    - context:
      {% for param, value in resolv_conf.items() %}
      {{ param }}: {{ value }}
      {% endfor %}
{%endif%}

netcfg_file__file_/etc/sysconfig/network:
  file.managed:
    - name: /etc/sysconfig/network
    - source: salt://netcfg/file/network.jinja
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - watch_in:
      - service: netcfg_file__service_networkrunning
    - require:
      - pkg: netcfg_file__pkg_bridge-utils
    - context:
      {% for param, value in salt['pillar.get']('netcfg:file:system', {}).items() %}
      {{ param }}: {{ value }}
      {% endfor %}

{% for managedif, managedifdata in salt['pillar.get']('netcfg:file:managed', {}).items() %}
netcfg_file__file_/etc/sysconfig/network-scripts/ifcfg-{{managedif}}:
  file.managed:
    - name: /etc/sysconfig/network-scripts/ifcfg-{{managedif}}
    - source: salt://netcfg/file/ifcfg.jinja
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - watch_in:
      - service: netcfg_file__service_networkrunning
    - require:
      - pkg: netcfg_file__pkg_bridge-utils
    - context:
      iface: {{managedif}}
      {% for param, value in managedifdata.items() %}
      {{ param }}: {{ value }}
      {% endfor %}
  {% if managedifdata.vlannumbers is defined and managedifdata.vlannumbers %}
  {% for vlannumber in managedifdata.vlannumbers %}    
  {% if managedifdata.vlanparams.type is defined and managedifdata.vlanparams.type == "Bridge" %}
netcfg_file__file_/etc/sysconfig/network-scripts/ifcfg-{{managedif}}vl{{vlannumber}}:
  {% else %}
netcfg_file__file_/etc/sysconfig/network-scripts/ifcfg-{{managedif}}.{{vlannumber}}:
  {% endif %}
  file.managed:
  {% if managedifdata.vlanparams.type is defined and managedifdata.vlanparams.type == "Bridge" %}
    - name: /etc/sysconfig/network-scripts/ifcfg-{{managedif}}vl{{vlannumber}}
  {% else %}
    - name: /etc/sysconfig/network-scripts/ifcfg-{{managedif}}.{{vlannumber}}
  {% endif %}
    - source: salt://netcfg/file/ifcfg.jinja
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - watch_in:
      - service: netcfg_file__service_networkrunning
    - require:
      - pkg: netcfg_file__pkg_bridge-utils
    - context:
      {% if managedifdata.vlanparams.type is defined and managedifdata.vlanparams.type == "Bridge" %}
      iface: {{managedif}}vl{{vlannumber}}
      {% else %}
      iface: {{managedif}}.{{vlannumber}}
      vlan: True
      {% endif %}
      {% for vlanparam, value in managedifdata.vlanparams.items() %}
      {{ vlanparam }}: {{ value }}
      {% endfor %}
      {% if managedifdata.vlanparams.basebridge is defined and managedifdata.vlanparams.basebridge %}
      bridge: {{managedifdata.vlanparams.basebridge}}vl{{vlannumber}}
      {% endif %}
  {% endfor %}
  {% endif %}
{% endfor %}

netcfg_file__service_networkenabled:
  service.enabled:
    - name: {{servicenetworkenabled}}
    - require:
      - pkg: netcfg_file__pkg_bridge-utils

{% if grains.get('netcfg_file__initial_run') != 'successful' %}

netcfg_file__initial_run_successful:
  module.run:
    - name: grains.setval
    - key: netcfg_file__initial_run
    - val: successful
    - require:
      - pkg: netcfg_file__pkg_bridge-utils
      - service: netcfg_file__service_networkenabled

netcfg_file__system_reboot:
  module.run:
    - name: system.reboot
    - require:
      - module: netcfg_file__initial_run_successful

netcfg_file__service_networkrunning:
  service.running:
    - name: {{servicenetworkenabled}}
    - require:
      - module: netcfg_file__system_reboot

{% else %}

netcfg_file__service_networkrunning:
  service.running:
    - name: {{servicenetworkenabled}}
    - require:
      - pkg: netcfg_file__pkg_bridge-utils

{% endif %}
