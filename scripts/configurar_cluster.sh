#!/bin/bash

##############################################################
#################### Funciones auxiliares ####################
##############################################################

# Función que elimina las líneas en blanco y las líneas comentadas del fichero pasado como 
# parámetro 1.
# El resultado se encuentra en fichero.
# Esta función se utiliza para el fichero de configuración ($1)
cribarFichA () {
	grep . /home/practicas/Documentos/$1 > aux
	while IFS= read -r line 
	do
		if [[ $line != *"#"* ]];
		then
			echo $line >> fichero
		fi
	done < aux
	rm aux	
}
# Función auxiliar que comprueba si la máquina destino (pasada como parámetro) es la misma que la
# que está ejecutando el script configurar_cluster.sh
mismaMaq () {
	var=$(hostname -I)
	array=(${var// / })

	if [ ${array[0]} == $1 ];
	then
		return 0
	else
		return 1
	fi
	
}

# Función que comprueba si la línea del fichero de configuración de servicios pasada como parámetro,
# es correcta o no.
lineaCorrecta () {
	var=$1
	a=(${var// / })
	DEST=${a[0]}
	SERV=${a[1]}
	FICH=${a[2]}
	if [ -z "$SERV" ] || [ -z "$FICH" ]
	then
		# Si solo tenemos 1 o 2 variables en vez de 3 es que el fichero es incorrecto.
		return 1
	else
		# Formato correcto
		return 0
	fi
}

####################################
######## Programa principal ########
####################################

#Eliminamos las líneas en blanco y los comentarios
cribarFichA "$1"
# Procesamos el fichero de configuración. Usamos un descriptor de fichero (10 en este caso)
# para poder usar las llamadas ssh.
echo "Ejecutamos el script:" $0
while IFS=: read -u10 line
do	
	echo
	#Comprobamos si la línea del fichero de configuración es correcta
	lineaCorrecta "$line"
	if [ $? -eq 1 ];
	then
		echo "Error en el fichero de configuración. La línea siguiente es incorrecta:"
		echo $line
		rm fichero
		exit 1
	fi
	#Comprobamos si tenemos que ejecutar el script local o remotamente.
	DIR=$(pwd)		# Directorio del 
	mismaMaq "$DEST"	
	if [ $? -eq 0 ];
	then
		# Destino y origen son la misma máquina. LOCAL
		$DIR/cfaux.sh $DEST $SERV $FICH
		if [ $? -ne 0 ];
		then
			#Si el script termina con errores lo notificamos y abortamos la ejecución.
			rm fichero
			exit 1
		fi

	else
		# REMOTO
		#Comprobamos si tenemos conexión con la máquina
		ssh -o StrictHostKeyChecking=no $DEST "ls" > /dev/null 2>&1
		if [ $? -ne 0 ];
		then
			echo "No hay conectividad con la máquina:" $DEST 1>&2
			rm fichero
			exit 1
		fi
		#Copiamos nuestro script y los ficheros necesarios en la máquina destino.
		scp * $DEST:/home/practicas/Documentos > /dev/null 2>&1

		#Ejecutamos el script que configura los distintos perfiles de servicio.
		# ssh -o StrictHostKeyChecking=no
		ssh -o StrictHostKeyChecking=no $DEST "/home/practicas/Documentos/cfaux.sh $DEST $SERV $FICH"
		if [ $? -ne 0 ];
		then
			#Si el script termina con errores borramos los ficheros copiados.
			ssh -o StrictHostKeyChecking=no $DEST "rm -f /home/practicas/Documentos/ !(backup.sh)" > /dev/null 2>&1
			rm fichero
			exit 1
		fi
		#Al terminar borramos los ficheros copiados remotamente
		ssh -o StrictHostKeyChecking=no $DEST "rm -f /home/practicas/Documentos/ !(backup.sh)" > /dev/null 2>&1
	fi
done 10< fichero
rm fichero
exit 0
