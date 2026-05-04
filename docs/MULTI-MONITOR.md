# Emiscreen - Guía de Multi-Monitor (Windows)

## Cómo usar tu Fire TV como pantalla secundaria REAL

### Paso 1: Configurar Windows en modo Extendido

1. **Presiona `Win + P`** en tu teclado
2. Selecciona **"Extender"** (Extend)

   ![Win+P menu](https://i.imgur.com/placeholder.png)

   O manualmente:
   - Click derecho en el escritorio → **"Configuración de pantalla"**
   - En "Pantallas múltiples" selecciona **"Extender estos pantallas"**

3. **La Fire TV ahora es tu monitor 2**

### Paso 2: Ver tus monitores detectados

```powershell
.\scripts\list-monitors.ps1
```

Salida esperada:
```
Connected monitors:
  1: \.\DISPLAY1 (1920x1200 @ 165Hz)
  2: \.\DISPLAY2 (1920x1080 @ 60Hz)
```

### Paso 3: Capturar solo el monitor secundario

```powershell
# Capturar TODO el escritorio (todos los monitores juntos)
emiscreen --source windows-pc

# Capturar SOLO el monitor 2 (la Fire TV)
emiscreen --source windows-pc --display 2

# Capturar SOLO el monitor 1 (tu laptop)
emiscreen --source windows-pc --display 1
```

### Paso 4: Mover aplicaciones al monitor 2

1. Arrastra la ventana de tu aplicación hacia la derecha (fuera de tu pantalla)
2. ¡Aparecerá en la Fire TV!

O usa atajos de Windows:
- `Win + Shift + ←/→` : Mover ventana entre monitores

---

## Ejemplos prácticos

### Escenario 1: Ver una película en la Fire TV mientras trabajas en la laptop

```powershell
# 1. Configura Windows en modo Extendido (Win + P → Extender)
# 2. Abre tu reproductor de video
# 3. Mueve el reproductor al monitor 2 (arrastra hacia la derecha)
# 4. Inicia Emiscreen capturando SOLO el monitor 2
emiscreen --source windows-pc --display 2 --quality balanced
```

### Escenario 2: Jugar en la Fire TV con controles

```powershell
# 1. Configura Windows en modo Extendido
# 2. Mueve el juego al monitor 2
# 3. Captura el monitor 2
emiscreen --source windows-pc --display 2 --quality fast
```

### Escenario 3: Presentación (modo espejo clásico)

```powershell
# Simplemente duplica la pantalla con Win + P → Duplicar
# Emiscreen captura automáticamente todo
emiscreen --source windows-pc
```

---

## Tabla de comandos

| Qué quieres hacer | Comando |
|-------------------|---------|
| Capturar todo el escritorio | `emiscreen --source windows-pc` |
| Capturar solo monitor 1 | `emiscreen --source windows-pc --display 1` |
| Capturar solo monitor 2 | `emiscreen --source windows-pc --display 2` |
| Modo espejo (duplicar) | `Win + P` → Duplicar, luego `emiscreen` |
| Modo extendido | `Win + P` → Extender, luego `emiscreen --display 2` |
| Ver monitores detectados | `.\scripts\list-monitors.ps1` |

---

## Solución de problemas

### "No detecta el monitor 2"
Asegúrate de que Windows realmente está en modo extendido:
```powershell
# Verifica en Settings → Display que dice "Extend these displays"
```

### "Se ve borroso en el monitor 2"
El monitor 2 podría tener una resolución diferente. Emiscreen escala automáticamente con lanczos para máxima nitidez.

### "Hay franjas negras"
Eso es normal si las resoluciones no coinciden. Emiscreen usa `object-fit: contain` para mantener el aspect ratio. Si quieres forzar que llene la pantalla (con posible deformación), eso requiere configuración avanzada.
