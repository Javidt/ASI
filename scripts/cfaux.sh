#!/bin/bash

##########################################################################
### Funciones auxiliares utilizadas por las funciones de los servicios ###
##########################################################################

#Función que recibe como parámetro un fichero y comprueba si existe
fichEx() {
	
	#DIR=$(pwd)
	test -f "/home/practicas/Documentos/"$1
}
directorioEx () {
	if [ -d $1 ]
	then
		#El directorio existe
		return 0
	else
		#El directorio no existe
		return 1
	fi
}

# Función que elimina las líneas en blanco y las líneas comentadas.
# El resultado se encuentra en fich
# Antes de llamar a la función se debe indicar en Fel fichero que se quiere transformar.
# Criba el fichero auxiliar pasado en F
cribarFichB () {
	grep . "/home/practicas/Documentos/"$1 > aux	
	while IFS= read -r line 
	do
		if [[ $line != *"#"* ]];
		then
			echo $line >> fich
		fi
	done < aux
	rm aux	
}
# Función que dado un fichero calcula el número de líneas que tiene
# sin contar las líneas en blanco ni las lineas comentadas.
# Calcula las lineas del fichero pasado como parámetro.
lineas () {
	cribarFichB "$1"
	CONT=0
	while IFS= read -r line 
	do
		CONT=$((CONT+1))
	done < fich
	rm fich
	return $CONT
}
# Función que escribe en "array" los 2 parámetros del fichero de configuración de mount.
# (Dispositvivo y Punto de montaje)
# Recibe como parámetro ($1) el fichero de perfil de servicios.
leerMount () {
	grep . "/home/practicas/Documentos/"$1 > aux
	CONT=0
	while IFS= read -r line 
	do
		if [[ $line != *"#"* ]];
		then
			array[ $CONT ]=$line
			CONT=$((CONT+1))
		fi
	done < aux
	rm aux
}
# Función que comprueba si un dispositivo existe o no.
# El dispositivo se recibe como parámetro
# $? = 0 si existe
# $? = 1 si no existe
deviceEx () {
	df $1 > /dev/null 2>&1
}

# Función que comprueba si el dispositivo pasado como parámetro tiene un SF montado.
# Devuelve 0 en caso de que no tenga nada montaod. Devuelve 1 e.o.c
alreadyMounted () {
	var=$(lsblk -o MOUNTPOINT $1)
	v=(${var// / })
	if [ ! -z ${v[1]} ];
	then
		return 1
	fi
	return 0
}
# Función que lee el fichero de perfil de servicios, escirbe en 3 variables los parámetros
# que necesitamos para configurar el servicio RAID. Y comprueba que estos parámetros sean
# correctos.
# Recibe como único parámetro el fichero de perfil de servicios.
# Las variables de salida son: NOM LEVEL y DEVICES
leerRaid () {
	cribarFichB "$1"
	CONT=0
	while IFS= read -r line 
	do
		if [ $CONT -eq 0 ];
		then
			# Primera línea: nombre de dispositivo RAID
			NOM=$line
			CONT=$((CONT+1))
		elif [ $CONT -eq 1 ];
		then
			# Segunda línea: nivel de RAID.			
			LEVEL=$line
			levelOk "$LEVEL"
			if [ $? -ne 0 ];
			then
				rm fich
				return 1
			fi
			CONT=$((CONT+1))
		else
			# Tercera línea: dispositivos que se añadirán al raid
			CONT=$((CONT+1))
			DEVICES=$line
			devOk "$DEVICES"
			if [ $? -ne 0 ];
			then
				rm fich
				return 1
			fi
		fi
	done < fich
	rm fich
	return 0
}

# Función que comprueba que el nivel del raid sea correcto.
# El nivel de raid se recibe como único parámetro.
# Se imprime por la salida de error estándar un mensaje notificando el error.
# (en caso de que lo hubiera)
levelOk () {
	#comprobamos que el número del raid es correcto
	if [ $1 == "0" ] || [ $1 == 1 ] || [ $1 == 4 ] || [ $1 == 5 ];
	then
		return 0
	else
		echo "error en el nivel de raid selecionado" 1>&2
		return 1
	fi
}
# Función que configura el cliente NIS
leerClientNis () {
	cribarFichB "$1"
	CONT=0
	while IFS= read -r line 
	do
		if [ $CONT -eq 0 ];
		then
			DOM=$line
			CONT=$((CONT+1))
		else
			MAQ=$line
			CONT=$((CONT+1))
		fi
	done < fich
	rm fich

	#Comprobamos que la dir IP es correcta
	M=$MAQ
	comprobarIP "$M"
	if [ $? -ne 0 ];
	then
		echo "Error de sintaxis. La dirección IP:" $MAQ "es incorrecta" 1>&2
		return 1
	fi

}
#Función auxiliar que comprueba si la Dir IP pasada como argumento tiene un formato correcto
comprobarIP () {
	ip=(${1//'.'/ })
	if [[ $MAQ =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
	then

		if [ ${ip[0]} -le 255 ] && [ ${ip[1]} -le 255 ] &&
			[ ${ip[2]} -le 255 ] && [ ${ip[3]} -le 255 ];
		then
			return 0
		else		
			return 1
		fi
	else
		return 1
	fi
}
# Función auxiliar que recibe como parámetro la línea del fichero de perfil de servicios del cliente
# NFS.
# Devuelve 0 (OK) o 1 (error) según sea correcta o no la línea en cuestión.
lineaNFSok () {
	line=$1
	a=(${line// / })
	HOST=${a[0]}
	MAQ=$HOST
	comprobarIP "$HOST"
	if [ $? -ne 0 ];
	then
		echo "Error de sintaxis. La dirección IP:" $HOST "es incorrecta" 1>&2
		return 1
	fi
	DIR_REM=${a[1]}
	DIR_LOC=${a[2]}
	if [ -z "$DIR_REM" ] || [ -z $DIR_LOC ] ;
	then
		return 1
	fi
	#¿El directorio local existe?
	if [ ! -d $DIR_LOC ];
	then
		#Si no existe el directorio local sobre el que montar los ficheros, lo creamos.
		sudo mkdir $DIR_LOC
	fi
	return 0
}
# Función que recibe como único parámetro una lista con los dispositivos
# del fichero de perfil de servicios del RAID.
# Devuelve el número de dispositivos que tenemos.
numDevices () {
	array=(${1// / })
	n=0
	cond=0
	while [ $cond -ne 1 ]
	do
		if [ -z ${array[$n]} ];
		then
			cond=1
			return $n
		fi
		n=$((n+1))
	done
	return $n

}
# Función que comprueba que ninguno de los dispositivos de la lista pasada como parámetro
# tenga un SF montado.
devOk () {
	array=(${1// / })
	n=0
	cond=0
	while [ $cond -ne 1 ]
	do
		# Ya no quedan más dispositivos
		if [ -z ${array[$n]} ];
		then
			cond=1
			return 0
		fi
		# Comprobamos que exista el dispositivo
		deviceEx "${array[$n]}"
		if [ $? -ne 0 ];
		then
			echo "ERROR: El dispositivo:" ${array[$n]} "no existe." 1>&2
			return 1
		fi
		# Comprobamos si el dispositivo tiene un SF montado
		alreadyMounted "${array[$n]}"
		if [ $? -ne 0 ];
		then
			echo "ERROR: El dispositivo:" ${array[$n]} "contiene un sistema de ficheros." 1>&2
			return 1
		fi
		n=$((n+1))
	done
	return 0
}
# Función auxiliar que comprueba que los parámetros para el montaje son correctos.
# Se recibe como parámetro el dispositivo ($1) y el punto de montaje ($2)
# Devuelve 0 en caso de que se pueda realizar sin problemas.
# Crea el directorio en cuestión si es necesario.
montajeOk () {
	COD=0
	#Comprobamos si existe el dispositivo.
	deviceEx "$DEVICE"
	EX=$?
	if [ $EX -ne 0 ]
	then
		#El dispositivo no existe. ERROR
		echo "El dispositivo: " $1 "no existe." 1>&2
		COD=$((COD+1))
	fi 
	#¿Existe el punto de montaje?
	if [ -d $PUNTO ]
	then
		if [ "$(ls $2)" ]
		then
			#El punto existe pero no se encuentra vacío. ERROR
			echo "el directorio no está vacío" 1>&2
			COD=$((COD+1))
		fi

	else
		#Si el punto no existe lo creamos. OK
		echo "El punto de montaje: " $2 "no existe, creando el punto..."
		sudo mkdir $2
	fi
	return $COD
}
# Función auxiliar que comprueba que los parámetros para el backup son correctos
# Devuelve 0 en caso de que se pueda realizar sin problemas. Y crear el directorio en cuestión
# si es necesario.
# Recibe: "$ORIGEN" "$SERVIDOR" "$DESTINO" "$PERIODO" "$DEST"
backupClientOk () {
	COD=0
	if [ ! -d $1 ]
	then
		echo "ERROR: El directorio origen no existe" 1>&2
		COD=$((COD+1))
	fi
	# Comprobamos si tenemos conexión con la máquina servidora
	ssh $SERVIDOR "ls /" > /dev/null 2>&1
	if [ $? -ne 0 ];
	then
		echo "ERROR: No existe conexión con el servidor"
		COD=$((COD+1))
	fi
	
	# Comprobamos si existe el directorio de la máquina destino
	ssh $SERVIDOR "ls $DESTINO" > /dev/null 2>&1
	if [ $? -ne 0 ];
	then
		echo "ERROR: No existe el directorio destino."
		COD=$((COD+1))
	fi
	# Comprobamos si la dirección IP tiene un formato correcto
	HOST=$SERVIDOR
	MAQ=$HOST
	comprobarIP "$HOST"
	if [ $? -ne 0 ];
	then
		echo "ERROR: Formato de la dirección IP del servidor incorrecto."
		COD=$((COD+1))
	fi
	return $COD
}
# Función auxiliar que comprueba que los parámetros para el backup son correctos
# Devuelve 0 en caso de que se pueda realizar sin problemas. Y crear el directorio en cuestión
# si es necesario.
backupServerOk () {
	COD=0
	if [ -d $PUNTO ]
	then
		#El punto de backup existe
		if [ "$(ls $1)" ]
		then
			#El punto existe pero no se encuentra vacío. ERROR
			echo "ERROR: El directorio no está vacío" 1>&2
			COD=$((COD+1))
		fi
	else
		#Si el punto no existe lo creamos. OK
		echo "El punto de backup: " $1 "no existe, creando el punto..."
		sudo mkdir -p $1
	fi
	return $COD
}

# Función que escribe en un array el parámetro del fichero de condiguración de backup_server.
# Recibe como parámetro ($1) el fichero de configuración.
leerBackup () {
	grep . "/home/practicas/Documentos/"$1 > aux
	CONT=0
	while IFS= read -r line
	do
		if [[ $line != *"#"* ]];
		then
			array[ $CONT ]=$line
			CONT=$((CONT+1))
		fi
	done < aux
	rm aux
}
#########################################################################
################ Funciones que implementan los servicios ################
#########################################################################

# Función principal que configura el servicio de montaje.
montaje() {
	fichEx "$FICH"
	if [ $? -ne 0 ];
	then
		#No existe el fichero. ERROR
		echo "El fichero" $FICH "no existe" 1>&2
		return 1
	fi
	#Comprobamos el número de líneas del fichero
	lineas "$FICH"
	NLINEAS=$?
	
	if [ $NLINEAS -ne 2 ]
	then
		#ERROR
		echo "Número de líneas del fichero de configuración incorrectas. (Deben ser 2 líneas)." 1>&2
		return 1
	else
		
		#Nº de lineas correcto, leemos el nombre del dispositivo y el pto de montaje
		declare -a array
		leerMount "$FICH"	#leemos el fichero de config del servicio en concreto
		DEVICE=${array[0]}	# nombre del dispositivo
		PUNTO=${array[1]}	# punto de montaje

		# Comprobamos si los parámetros del servicio es correcto
		montajeOk "$DEVICE" "$PUNTO" 
		if [ $COD -eq 0 ]
		then
			#Si nos ha dado 0 como código de retorno es que se puede hacer el montaje.OK
			sudo mount $DEVICE $PUNTO > /dev/null 2>&1			
			sudo echo $DEVICE $PUNTO "auto auto,rw,users,umask=000 0 0" >> /etc/fstab
		else
			#Devolvemos un código de error != 0
			return $COD
		fi
	fi

} # final montaje

# Función principal que ejecuta el método raid.
raid () {
	#comprobamos que exista el fichero
	fichEx "$FICH"
	if [ $? -ne 0 ]
	then
		#No existe el fichero. ERROR
		echo "ERROR: El fichero no existe" 1>&2
		return 1
	fi
	# Calculamos el número de líneas del fichero de perfil de servicios
	
	lineas "$FICH"
	NLINEAS=$?
	if [ $NLINEAS -ne 3 ]
	then
		# Error número de líneas
		echo "ERROR: Número de líneas del fichero de configuración incorrectas. (Deben ser 3 líneas)." 1>&2
		return 1
	else
		#Comprobamos si el paquete mdadm está instalado
		sudo apt-get -yq update > /dev/null 2>&1
		dpkg -s mdadm > /dev/null 2>&1
		if [ $? -ne 0 ];
		then
			# En caso de que no esté instalado lo instalamos:
			sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq mdadm > /dev/null 2>&1
		fi
		# Comprobamos que los parámetros son correctos y los guardamos en NOM, LEVEL y DEVICES
		leerRaid "$FICH"
		# ¿Algún parámetro es incorrecto?
		if [ $? -ne 0 ];
		then
			return 1
		fi
		numDevices "$DEVICES"
		n=$?
		# Configuramos el raid
		echo y | sudo mdadm --create --level=$LEVEL --raid-devices=$n $NOM $DEVICES > /dev/null 2>&1
		if [ $? -ne 0 ];
		then
			echo "ERROR: El nombre" $NOM "del RAID es incorrecto."
			return 1
		fi
		# Guardamos la configuración
		sudo cat /etc/mdadm/mdadm.conf > mdconf
		sudo mdadm --detail $NOM --brief >> mdconf
		sudo rm /etc/mdadm/mdadm.conf
		sudo cp mdconf /etc/mdadm/mdadm.conf
		sudo rm mdconf

		return 0
	fi	
} # final raid

# Función principal que configura el servicio LVM.
lvm () {
	#Comprobamos si el paquete lvm se encuentra en la máquina
	sudo apt-get update -yq > /dev/null 2>&1
	sudo apt-get -yq update > /dev/null 2>&1
	dpkg -s lvm2 > /dev/null 2>&1
	if [ $? -ne 0 ];
	then
		# En caso de que no esté instalado lo instalamos:
		sudo apt-get install -yq lvm2* > /dev/null 2>&1
	fi
	#Comprobamos si existe el fichero de prefil de servicios.
	fichEx "$FICH"
	if [ $? -ne 0 ];
	then
		#No existe el fichero. ERROR
		echo "ERROR: El fichero" $1 "no existe" 1>&2
		return 1
	fi
	#Comprobamos el número de líneas del fichero
	lineas "$FICH"
	NLINEAS=$?
	if [ $NLINEAS -lt 3 ]
	then
		#ERROR
		echo "ERROR: Número de líneas del fichero de configuración incorrectas. (Deben ser 3 o más líneas)." 1>&2
		return 1
	else
	# Eliminamos las líneas en blanco y las líneas comentadas.
	cribarFichB "$FICH"
	CONT=0
	while IFS=: read -r linea
	do
		if [ $CONT -eq 0 ]
		then
			#guardamos el nombre del grupo del volúmenes
			NOMBRE=$linea
		elif [ $CONT -eq 1 ]
		then		
			#lista de dispositivos
			DISP=$linea
			# ¿Existen los dispositivos?
			lsblk $DISP > /dev/null 2>&1	
			if [ $? -ne 0 ];
			then
				# Error
				echo "ERROR: Al menos un dispositivo no existe." 1>&2
				return 1
			fi

			#¿Existe previamente el nombre del grupo?
			sudo pvcreate $DISP > /dev/null 2>&1
			if [ $? -ne 0 ]
			then
				# Error
				echo "ERROR: Los volúmenes físicos ya están inicializados" 1>&2
				return 1
			fi
				# OK
				sudo vgcreate $NOMBRE $DISP > /dev/null 2>&1
			if [ $? -ne 0 ]
			then
				# Error
				echo "ERROR: Ya existe otro grupo con ese nombre." 1>&2
				return 1
			fi
		else
			array=(${linea// / })
			VNOM=${array[0]}
			TAM=${array[1]}

			# Creamos los volúmenes lógicos
			sudo lvcreate --name $VNOM --size $TAM $NOMBRE > /dev/null 2>&1
			if [ $? -ne 0 ]
			then
				# Error
				echo "El tamaño del volumen lógico excede el tamaño del grupo de volúmenes." 1>&2
				return 1	
			fi	
		fi
		CONT=$((CONT+1))
	done < fich
	CONT=0
	rm fich
	return 0
	fi
} # final LVM

# Función principal que configura el cliente NIS.
nis_client () {
	fichEx "$FICH"
	if [ $? -ne 0 ];
	then
		# No existe el fichero. ERROR
		echo "ERROR: El fichero" $FICH "no existe" 1>&2
		return 1
	fi
	# Comprobamos el número de líneas del fichero
	lineas "$FICH"
	NLINEAS=$?
	if [ $NLINEAS -ne 2 ]
	then
		#ERROR
		echo "ERROR: Número de líneas del fichero de perfil de servicios incorrecto. (Deben ser 2 líneas)." 1>&2
		return 1
	else
		#Instalamos los paquetes necesarios para nis.
		dpkg -s nis > /dev/null 2>&1
		if [ $? -ne 0 ];
		then
			# En caso de que no esté instalado lo instalamos:
			sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install nis > /dev/null 2>&1
		fi
		# Guardamos los parámetros para la configuración del servicio.
		leerClientNis "$FICH"
		if [ $? -ne 0 ];
		then
			# Error
			return 1	
		fi		
		# Configuramos el cliente nis
		# En caso de que anteriormente estuviera como servidor, ahora es cliente
		sudo sed -i 's/NISSERVER=master/NISSERVER=false/g' /etc/default/nis
		
		#Modificamos /etc/yp.conf
		cat /etc/yp.conf > otro1
		sudo echo "domain" $DOM "server" $MAQ >> otro1
		sudo rm /etc/yp.conf
		sudo cp otro1 /etc/yp.conf		
		sudo rm otro1

		# Cambiamos el nombre de dominio NIS 
		sudo domainname $DOM
		sudo rm /etc/defaultdomain
		sudo echo $DOM > otro
		sudo cp otro /etc/defaultdomain
		sudo rm otro

		#Lanzamos el servicio
		sudo service nis restart > /dev/null 2>&1
		return 0
	fi
} # final cliente NIS

# Función principal que configura el servidor NIS.
nis_server () {
	fichEx "$FICH"
	if [ $? -ne 0 ];
	then
		#No existe el fichero. ERROR
		echo "ERROR: El fichero" $FICH "no existe" 1>&2
		return 1
	fi
	# Comprobamos el número de líneas 
	lineas "$FICH"
	NLINEAS=$?
	if [ $NLINEAS -ne 1 ]
	then
		#ERROR
		echo "ERROR: Número de líneas del fichero de configuración incorrectas. (Deben ser 1 línea)." 1>&2
		return 1
	else
		# Eliminamos las líneas en blanco y las lineas comentadas
		cribarFichB "$FICH"
		DOM=$(cat fich)
		#Instalamos los paquetes necesarios para nis.
		sudo apt-get update -yq > /dev/null 2>&1
		dpkg -s nis > /dev/null 2>&1
		if [ $? -ne 0 ];
		then
			# En caso de que no esté instalado lo instalamos:
			sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install nis > /dev/null 2>&1
		fi
		# Configuramos el servidor nis
		# Configuramos nuestra máquina como NIS master
		sudo sed -i 's/NISSERVER=false/NISSERVER=master/g' /etc/default/nis
		#sudo sed -i 's/NISCLIENT=true/NISCLIENT=false/g' /etc/default/nis
		# Permitimos el acceso a todos los equipo de nuestra red.
		sudo rm /etc/ypserv.securenets
		sudo echo "255.0.0.0 127.0.0.0" > otro
		sudo echo "255.255.255.0 10.0.2.0" >> otro
		sudo cp otro /etc/ypserv.securenets
		sudo rm otro
		# Modificamos el fichero /var/yp/Makefile
		sudo sed -i 's/MERGE_PASSWD=false/MERGE_PASSWD=true/g' /var/yp/Makefile
		sudo sed -i 's/MERGE_GROUP=false/MERGE_GROUP=true/g' /var/yp/Makefile

		# Cambiamos el nombre de dominio NIS
		sudo domainname $DOM
		sudo rm /etc/defaultdomain
		sudo echo $DOM > otro
		sudo cp otro /etc/defaultdomain
		sudo rm otro
		# Actualizamos los cambios
		echo EOF | sudo /usr/lib/yp/ypinit -m > /dev/null 2>&1
		# Arrancamos el servicio
		sudo service nis restart > /dev/null 2>&1
		rm fich
		return 0
	fi
} # final servidor NIS

# Función principal que configura el servidor NFS.
nfs_server () {
	# Comprobamos si el fichero existe
	fichEx "$FICH"
	if [ $? -ne 0 ];
	then
		#No existe el fichero. ERROR
		echo "El fichero" $FICH "no existe" 1>&2
		return 1
	fi
	# Eliminamos las líneas en blanco y las líneas comentadas
	cribarFichB "$FICH"
	COD=0
	# Copiamos el fichero de exportaciones en un fichero auxiliar
	cat /etc/exports > otro	
	#¿Está instalado el paquete del servidor?
	dpkg -s nfs-kernel-server > /dev/null 2>&1
	if [ $? -ne 0 ];
	then
		# En caso de que no esté instalado lo instalamos:
		sudo apt-get install -y nfs-kernel-server  > /dev/null 2>&1
	fi
	# Bucle de lectura del fichero de perfil de servicios, cada línea un directorio
	while IFS=: read -r linea
	do
		# Comprobamos la línea del fichero. Se crea el directorio en caso de ser necesario.
		directorioEx "$linea"
		if [ $? -eq 0 ];
		then
			#Añadimos a /etc/exports el directorio que se exporta
			sudo echo $linea "10.0.2.0/24(rw,no_root_squash)" >> otro #Escribimos la línea
		else
			#El directorio no existe
			echo "ERROR: El directorio:" $linea "no existe" 1>&2
			COD=$((COD+1))
		fi
	done < fich
	
	sudo rm /etc/exports		# Eliminamos el fichero antiguo
	sudo cp otro /etc/exports	# Actualizamos el fichero
	rm fich				
	rm otro
	sudo service nfs-kernel-server restart > /dev/null 2>&1 # Arrancamos el servicio nis
	return $COD
} # final servidor NFS

# Función principal que configura el cliente NFS.
nfs_client () {
	fichEx "$FICH"
	if [ $? -ne 0 ];
	then
		#No existe el fichero. ERROR
		echo "ERROR: El fichero" $FICH "no existe"
		return 1
	fi
	#Hacemos una lectura de las líneas del fichero, cada línea un directorio
	cribarFichB "$FICH"
	COD=0
	cat /etc/fstab > otro	
	dpkg -s nfs-common > /dev/null 2>&1
	if [ $? -ne 0 ];
	then
		# En caso de que no esté instalado lo instalamos:
		sudo apt-get -y install nfs-common  > /dev/null 2>&1
	fi
	while IFS=: read -r linea
	do
		lineaNFSok "$linea"
		if [ $? -eq 0 ];
		then
			#Montamos el directorio
			sudo mount -t nfs $HOST:$DIR_REM $DIR_LOC
			#Añadimos el cambio al fichero /etc/fstab
			sudo echo $HOST:$DIR_REM $DIR_LOC "nfs defaults 0 0" >> otro
		else
			# La línea no es correcta
			echo "ERROR: La línea:" $linea 1>&2
			echo "Del fichero de perfil de servicios nfs_client.conf es incorrecta." 1>&2
			COD=$((COD+1))
		fi
	done < fich
	sudo rm /etc/fstab		#Eliminamos el fichero antiguo
	sudo cp otro /etc/fstab
	rm fich
	sudo service nfs-kernel-server restart > /dev/null 2>&1
	return $COD
} # final cliente NFS


# Función que realiza el backup del servidor
backup_server () {
	fichEx "$FICH"
	if [ $? -ne 0 ];
	then
		#No existe el fichero. ERROR
		echo "ERROR: El fichero no existe" $FICH
		return 1
	fi
	#Comprobamos el número de líneas del fichero
	lineas "$FICH"
	NLINEAS=$?
	if [ $NLINEAS -ne 1 ]
	then
		#ERROR
		echo "ERROR: Número de líneas del fichero de configuración incorrectas. (Debe ser 1 línea)."
		return 1
	else
		#Nº de líneas correcto, leemos directorio para el backup servidor.
		leerBackup "$FICH"	#Leemos el fichero de config del servicio en concreto
		PUNTO=${array[0]}	#Punto del backup
		# Comprobamos si los parámetros son correctos
		backupServerOk "$PUNTO"
		if [ $COD -ne 0 ]
		then
			# Ha habido algún fallo en los parámetros
			return 1
		fi
	fi
	return $COD
}

# Función que realiza el backup_client
backup_client () {
	fichEx "$FICH"
	if [ $? -ne 0 ];
	then
		#No existe el fichero. ERROR
		echo "ERROR: El fichero:" $FICH "no existe"
		return 1
	fi
	#Comprobamos el número de líneas del fichero
	lineas "$FICH"
	NLINEAS=$?
	if [ $NLINEAS -ne 4 ]
	then
		#ERROR
		echo "ERROR: Número de líneas del fichero de configuración incorrectas. (Debe ser 4 líneas)."
		return 1
	else
		#Nº de líneas correcto, leemos directorio para el backup cliente.
		leerBackup "$FICH"	#Leemos el fichero de config del servicio en concreto
		ORIGEN=${array[0]}	#Origen de los datos que queremos hacer backup
		SERVIDOR=${array[1]}	#Dirección del servidor del backup
		DESTINO=${array[2]}	#Destino de los datos donde hacemos backup
		PERIODO=${array[3]}	#Periodo de 24 horas
		backupClientOk	"$ORIGEN" "$SERVIDOR" "$DESTINO"
		if [ $COD -eq 0 ]
		then
			#Si nos ha dado 0 como código de retorno es que es posible realizar el backup.OK
			sudo rsync --recursive $ORIGEN $SERVIDOR:$DESTINO

			if [ $? -ne 0 ];
			then
				echo "ERROR: No tenemos permisos suficientes" 1>&2
				return 1
			fi
			# Configuramos cron para que el backup se realice periódicamente.
			sudo echo "0 */$PERIODO * * * ./backup.sh $ORIGEN $SERVIDOR $DESTINO" >> mycron
			sudo crontab mycron		#Instalamos nuevo crontab
			sudo rm mycron			#Borramos fichero mycron
			return 0
		else 
			# Parámetros de configuración incorrectos
			return 1
		fi
		
	fi
	return $COD
}

### MAIN ###

# Recibimos como parámetro la línea del fichero de configuración
	# DEST=$1 SERV=$2 FICH=$3
	# FICH = fichero de perfil de  servicio
FICH=$3

# Comprobamos qué servicio estamos ejecutando y llamamos a la función correspondiente
# que ejecuta dicho servicio.

if [ $2 == "mount" ];
then
	echo "Realizando el montaje del dispositivo $DEVICE "en el punto" $PUNTO de la máquina:" $1
	montaje
	if [ $? -eq 0 ]; 
	then
		echo "Montaje del dispositivo realizado con éxito."
		exit 0
	else
		echo "Montaje abortado"
		exit 1
	fi
elif [ $2 == "raid" ];
then
	echo "Realizamos la configuración del RAID de la máquina:" $1
	raid
	if [ $? -eq 0 ]; 
	then
		echo "Configuración del RAID completada con éxito."
		exit 0
	else
		echo "Configuración del RAID abortada."
		exit 1
	fi
elif [ $2 == "lvm" ];
then
	echo "Realizando la configuración del servicio LVM en la máquina:"
	echo $1
	lvm
	if [ $? -eq 0 ]; 
	then
		echo "El servicio LVM ha sido configurado con éxito."
		exit 0
	else
		echo "No se ha podido completar la configuración del servicio LVM en la máquina." 
		rm fich
		exit 1
	fi
elif [ $2 == "nis_server" ];
then
	echo "Realizando la configuración del servidor NIS en la máquina:"
	echo $1
	nis_server
	if [ $? -eq 0 ]; 
	then
		echo "La configuración del servidor NIS se ha completado con éxito."
		exit 0
	else
		echo "No se ha podido completar la configuración del servidor NIS en la máquina." 
		rm fich
		exit 1
	fi

elif [ $2 == "nis_client" ];
then
	echo "Realizando la configuración del cliente NIS en la máquina:"
	echo $1
	nis_client
	if [ $? -eq 0 ]; 
	then
		echo "La configuración del cliente NIS se ha completado con éxito."
		exit 0
	else
		echo "No se ha podido completar la configuración del cliente NIS en la máquina." 
		rm fich
		exit 1
	fi
elif [ $2 == "nfs_server" ];
then
	echo "Realizando la configuración del servidor NFS en la máquina:"
	echo $1
	nfs_server
	if [ $? -eq 0 ]; 
	then
		echo "La configuración del servidor NFS se ha completado con éxito."
		exit 0
	else
		echo "No se ha podido completar la configuración del servidor NFS en la máquina." 
		rm fich
		exit 1
	fi

elif [ $2 == "nfs_client" ];
then
	echo "Realizando la configuración del cliente NFS en la máquina:"
	echo $1
	nfs_client
	if [ $? -eq 0 ]; 
	then
		echo "La configuración del cliente NFS se ha completado con éxito."
		exit 0
	else
		echo "No se ha podido completar la configuración del cliente NFS en la máquina." 
		rm fich
		exit 1
	fi
elif [ $2 == "backup_server" ];
then
	echo "Realizando la configuración del servidor de backup en la máquina:"
	echo $1
	backup_server
	if [ $? -eq 0 ]; 
	then
		echo "La configuración del servidor de backup se ha completado con éxito."
		exit 0
	else
		echo "No se ha podido completar la configuración del servicio de backup en la áquina." 
		exit 1
	fi

elif [ $2 == "backup_client" ];
then
	echo "Realizando la configuración del cliente de backup en la máquina:"
	echo $1
	backup_client
	if [ $? -eq 0 ]; 
	then
		echo "La configuración del cliente de backup se ha completado con éxito."
		exit 0
	else
		echo "No se ha podido completar la configuración del cliente de backup en la máquina." 
		exit 1
	fi
else
	echo "El servicio:" $2 "es incorrecto"
	exit 1
fi
