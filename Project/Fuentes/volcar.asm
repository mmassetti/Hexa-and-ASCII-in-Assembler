%define sys_exit 1        ; Finaliza el proceso actual
%define sys_read 3        ; Lee del descriptor de archivo
%define sys_write 4       ; Escribe en el descriptor de archivo
%define sys_open 5        ; Abrir archivo (o dispositivo)
%define sys_close 6       ; Cerrar un descriptor de archivo

%define stdout 1          ; Salida por default

%define exit_success 0	  ; Terminacion normal
%define exit_fail 1		  ; Terminacion anormal
%define exit_ffile 2	  ; Terminacion anormal por error en el archivo de entrada
		
section	.data 							; Segmento de datos inicializados

	mensajeerror db "Error, el programa ha finalizado anormalmente ",Nueva_Linea 	; Mensaje de error
	mensajeerrorl equ $ - mensajeerror						    					; Longitud del mensaje

	mensajeerrorArchivo db "Error archivo de entrada defectuoso ",Nueva_Linea		; Mensaje de error por archivo
	mensajeerrorArchivol equ $ - mensajeerrorArchivo			        			; Longitud del mensaje
	
	letraH db '-h'   						; Cadena '-h',utilizada para comparar con la cadena ingresada por consola
	letraHl equ $- letraH 					; Longitud de la cadena	
	Nueva_Linea: equ 0ah					; Salto de linea
	TablaAscii: db '................................ !"',"#$%&'()*+,-./0123456789:;"	; Mapeo de entero a Ascii
	            db '<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz'
	            db '{|}~...........................................................'
	            db '...............................................................'
	            db '.......'
	align 4
	DireccionBase db '00000000  '										; Representacion de la direccion base
	DireccionBasel: equ $-DireccionBase									; Largo de la direccion base
	Plantilla: db '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ' 	; Plantilla Hexa	
	DivPos:   db '| '													; Caracter separador
	ParteAscii: db '................ |',Nueva_Linea						; Plantilla seccion Ascii
	Plantillal: equ $-Plantilla
	align 2
	TablaHexa:db '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2'	; Mapeo tabla hexa
	          db '02122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40'
	          db '4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606'
	          db '162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f8081'
	          db '82838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a'
	          db '2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2'
	          db 'c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e'
	          db '3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff'

	archivo_ayuda dd 'ayuda.txt' 		; Ruta de archivo de ayuda

	; Variables utilizadas para crear la direccion base

	offset: dd 2		; Es el desplazamiento para llevar las bases
	base: dd 0 			; Lleva el puntero de los ultimos 3 digitos de la direccion base , vuelve a 0 cada 16 iteraciones (16*16)
	base2: dd 0			; Lleva el puntero de los anteultimos 3 digitos de la direccion base , vuelve a 0 cada 256 iteraciones (16*16)
	base3: dd 0			; Lleva el puntero de los primeros 2 digitos de la direccion base , vuelve a 0 cada 65536 iteraciones (256*16)
	cont_2 dd 256		; Flag para determinar el numero de iteraciones utilizado en base2 . if(cont==0) {base2=0 , cont=256} 
	cont_3 dd 65536		; Flag para determinar el numero de iteraciones utilizado en base3 . if(cont==0) {base3=0 , cont=65536} 

section .bss								; Segmento de datos no inicializados

	mensajeayudal : equ 1024				; Mensaje de ayuda
	mensajeayuda resb 1024			  		; Longitud del buffer de ayuda
							
	Bufferl: equ 16							; Largo del buffer utilizado para procesar el archivo de entrada
	Buffer: resb Bufferl					; Reserva el largo para el buffer
	fd_in  resb 1							; Descriptor de entrada
	fd_out resb 1 							; Descriptor de salida (por defecto la consola)


section	.text	
							; Contenido del programa 
   	global _start         
	
_start:                						; Comienzo del programa

	pop edi									; Cantidad de argumentos
	cmp edi,1								; Hay un solo argumento ?
	je Error								; Si hay un solo argumento (no hay parametros) , error
		
	cmp edi,3								; Hay 3 argumentos ?
	jbe ControlarParametros					; Si hay 3 o menos argumentos (1 o 2 parametros), los controlo
	jnl Error								; No puede haber mas de 2 parametros
	
ControlarParametros:	

	pop ebx									; Nombre del programa, se descarta
	pop ebx									; Puntero al string, puede ser -h o la entrada
	mov dl,[ebx]							; Se guarda en dl el primer caracter de ebx 
	mov cl,[letraH]							; Se guarda en cl el primer caracter de letraH (es un -)
	cmp dl,cl								; dl==cl?
	jne ArchivoEntrada						; No se encontro el "-h" , necesariamente es el archivo de entrada.
	inc ebx									; Se avanza al siguiente caracter de ebx
	mov dl,[ebx]							; Se guarda en dl el segundo caracter de ebx 
	mov cl,[letraH+1]						; Se guarda en cl el segundo caracter de letraH (es una h)
	cmp dl,cl								; dl==cl?
	jne Error 								; Si no se encuentra una 'h' , error
	inc ebx									; Se avanza al siguiente caracter 
	mov dl,[ebx]							; Se guarda en dl el tercer caracter de ebx
	cmp dl,0 								; Se controla que el siguiente caracter sea nulo
	je Ayuda  								; Muestra el mensaje de ayuda en pantalla
	
ArchivoEntrada:	

	mov eax,sys_open	       				; Abre el archivo
	mov ecx, 0             					; Para acceder al modo de lectura
	mov edx, 0777          					; Se otorgan permisos para leer,escribir y ejecutar
	int 0x80								; Llamada al sistema	
   	mov [fd_in],eax							; La nueva entrada ahora es el archivo

Proceso:									; Se cargan 16 bytes del archivo al buffer

        mov ebx,[fd_in]						; El archivo sera nuestra entrada
        lea ecx,[Buffer]					; Se hace el load de la direccion efectiva
        mov edx,Bufferl						; Cantidad de bytes a leer (16 bytes)
        mov esi,Bufferl						; El registro ESI lo utilizamos como un contador

Completar:

        mov eax,sys_read					; Se realiza la lectura del archivo
        int 0x80                           	; LLamada al sistema

        cmp eax,0                         	; EAX == 0 ?
        jl ErrorArchivo                   	; Si es mayor a 0 , hubo un error con el archivo de entrada
        jz Ultima                         	; Si EAX == 0 , Fin del archivo

        add ecx, eax                        ; Actualiza donde cargar los datos
        sub edx, eax                        ; Calcula la cantidad de bytes que faltan
        jnz Completar                       ; Sigue llenando hasta obtener 16 bytes

        ; En este punto , tenemos leidos exactamente 16 bytes

        call LineaDeSalida               	; Se mueve la cantidad "[esi]" de bytes del buffer hacia 
                                          	; la plantilla y se imprime.

        jmp Proceso                       	; Obtener la siguiente linea.

; En este momento se llega al fin del archivo ( eax == 0 ) , se deben
; colocar los caracteres restantes en el buffer. 

Ultima:

        sub esi, edx                      	; Cuantos caracteres restantes se deben procesar ?
        jz Fin                            	; Se finalizo exactamente en 16 Bytes ?

        ; En caso contrario se rellenan las plantillas correspondientes con "blancos" --> ' '
        mov bx, 0x2020                    
        mov edx,Bufferl

EscribirBlancos:

        dec edx								
        mov [Plantilla+edx*2+edx],bx       ; Escribir blancos en la Plantilla (Parte Hexa)
        mov [ParteAscii+edx],bl            ; Escribir blancos en la ParteAscii (Parte Ascii)
        jnz EscribirBlancos

        call LineaDeSalida                 ; Mueve la cantidad "[esi]" de bytes del buffer hacia 
                                           ; la plantilla y la imprimimos.
                                 
; Salida del programa 

Fin:    mov ebx,exit_success               ; Terminacion normal
Exit:   
	
    ; Se cierran los archivos
    mov eax,sys_close
    mov ebx, [fd_in]

	mov eax,sys_exit
    int 0x80

Error:  									; Terminacion anormal  

	mov eax,sys_write					   	; Llamanda a sys_write 
	mov ebx,stdout						   	; Se imprimira en consola
	mov ecx,mensajeerror				   	; el mensaje de error
	mov edx,mensajeerrorl				   	; Longitud del mensaje de error
	int 0x80							   	; Llamada al sistema
	mov ebx,exit_fail               	   	; Salida anormal
    jmp Exit

ErrorArchivo: 							   	; Terminacion anormal por error en archivo de entrada

	mov eax,sys_write					   	; LLamada a sys_write 
	mov ebx,stdout						   	; Se imprime en consola
	mov ecx,mensajeerrorArchivo     	   	; el mensaje de error
	mov edx,mensajeerrorArchivol			; Longitud del mensaje de error
	int 0x80								; Llamada al sistema
	mov ebx,exit_ffile              		; Terminacion anormal , problemas con el archivo
    jmp Exit

Ayuda:	

	;Se abre el archivo
	mov eax,sys_open					    
	mov ebx, archivo_ayuda				    ; Abre el archivo de ayuda
	mov ecx, 0             				    ; Para acceder al modo de lectura
	mov edx, 0777          				    ; Se otorgan permisos para leer,escribir y ejecutar
	int 0x80								; Llamada al sistema	

   	mov [fd_in],eax						    ; La nueva entrada ahora es el archivo
	    
   	;Lectura del archivo de ayuda 
   	mov eax, sys_read
   	mov ebx, [fd_in]
   	mov ecx, mensajeayuda
   	mov edx, mensajeayudal
   	int 0x80
	
	mov eax,sys_write						; LLamada a sys_write 
	mov ebx,stdout							; Se escribe en consola
	mov ecx,mensajeayuda					; el mensaje de ayuda
	mov edx,mensajeayudal					; Longitud del mensaje de ayuda
	int 0x80								; Llamada al sistema
	mov ebx,exit_success					; Terminacion exitosa
	jmp Exit

; Parametros de entrada: esi: Cantidad de caracteres del Buffer a procesar
; Registros utilizados: eax, ebx, edx, edx, esi

LineaDeSalida:

        xor eax, eax

CharSiguiente:                          	; Procesar char siguiente

    dec esi
    mov al,[Buffer+esi]               		; Leer byte del Buffer
    mov bx,[TablaHexa+eax*2]          		; Obtener los simbolos correspondientes
    mov [Plantilla+esi*2+esi],bx      		; Escribir en la plantilla
    mov bl,[TablaAscii+eax]           		; Obtener el simbolo Ascii
    mov [ParteAscii+esi],bl           		; Escribir en la plantilla
    jnz CharSiguiente                 		; ecx es un offset
	
	; Se pisan los valores en las posiciones 6 y 7 del molde DireccionBase 00000XX0 

	mov eax,DWORD[base] 					; Se carga el valor de base en eax
	mov bx,[TablaHexa+1*eax]  				; Mapeo de acuerdo a la base
	mov [DireccionBase+5],bx 				; Se inicializa la DireccionBase
	mov eax,DWORD[base] 					; Se carga el valor de base en eax
	add eax,[offset] 						; Se suma el offset a realizar en eax
	mov [base],eax   						; base = base + offset

	; Se pisan los valores en las posiciones 4 y 5 del molde DireccionBase 000XX000 

	mov eax,DWORD[base2]	
	mov bx,[TablaHexa+1*eax]  	 			; Mapeo el digito 
	mov [DireccionBase+3],bx	 			; Se vuelve a escribir en el molde

	; Se pisan los valores en las posiciones 2 y 3 del molde DireccionBase 0XX00000 

	mov eax,DWORD[base3]
	mov bx,[TablaHexa+1*eax]  	 			; Mapeo el digito 
	mov [DireccionBase+1],bx 	 			; Vuelvo a escribir en el molde

	; Cada 256 (16*16) lineas se aumenta la base2, base2=base2+offset

	mov eax,[cont_2]
	cmp eax,0
	jz ResetContador1

	; Cada 65536 (256*256) lineas se debe aumentar la base3

	mov eax,[cont_3]
	cmp eax,0
	jz ResetContador2

	; Se decrementa el contador cont_2 (256)
	mov eax,[cont_2]
	sub eax,1
	mov [cont_2],eax

	; Se decrementa el contador cont_3 (65536)
	mov eax,[cont_3]
	sub eax,1
	mov [cont_3],eax

	; Se imprime la direccion base en la consola

	mov eax,sys_write
    mov ebx,stdout
    mov ecx,DireccionBase
    mov edx,DireccionBasel
    int 0x80

    ; Se imprime la Plantilla hexa en consola

    mov eax,sys_write
    mov ebx,stdout
    mov ecx,Plantilla
    mov edx,Plantillal
    int 0x80
    cmp eax,Plantillal
    jne Error

    ret

ResetContador1:	; Cuando el cont_2 == 0 , la base==0 y base2=base2+offset (	Esto se produce cada 256 iteraciones )

	;Reset a la base
	mov eax,0
	mov [base],eax
	;Reset el cont_2
	mov eax,256
	mov [cont_2],eax	
	;Empiezo a mover el offset para base2
	mov eax,DWORD[base2]
	add eax,[offset]
	mov [base2],eax
	ret

ResetContador2: ; Cuando el cont_3 == 0 , la base2==0 y base3=base3+offset ( Esto se produce cada 65536 iteraciones )

	;Reset a la base2
	mov eax,0
	mov [base2],eax
	;Reset el cont_3
	mov eax,65536
	mov [cont_3],eax	
	;Empiezo a mover el offset para base3
	mov eax,DWORD[base3]
	add eax,[offset]
	mov [base3],eax
	ret
