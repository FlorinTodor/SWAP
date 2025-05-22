#!/bin/bash

# Script de configuración de IPTABLES para contenedores web
# Autor: Florin Emanuel Todor Gliga

# IP del balanceador de carga (ajustar si cambia)


BALANCER_IP="192.168.10.50"

# Establecer políticas por defecto (Denegación implícita), es decir, denegar todo el tráfico entrante y saliente , ya que no tenemos reglas de aceptación
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Permitir tráfico en la interfaz de loopback (localhost)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir tráfico de conexiones ya establecidas o relacionadas (entrante)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Permitir tráfico de conexiones nuevas, establecidas y relacionadas (saliente)
iptables -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Permitir tráfico HTTP (puerto 80) desde el balanceador
iptables -A INPUT -p tcp -s $BALANCER_IP --dport 80 -j ACCEPT

# Permitir tráfico HTTPS (puerto 443) desde el balanceador
iptables -A INPUT -p tcp -s $BALANCER_IP --dport 443 -j ACCEPT

# Permitir tráfico para el puerto 9100 desde la subred

PROMETHEUS_IP="192.168.10.100"
iptables -A INPUT -p tcp -s $PROMETHEUS_IP --dport 9100 -j ACCEPT

iptables -A INPUT -p tcp -s 192.168.10.0/24 --dport 9100 -j ACCEPT