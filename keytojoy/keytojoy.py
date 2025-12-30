import vgamepad as vg
from pynput import keyboard
import time

# Inicializa o controle virtual do Xbox
gamepad = vg.VX360Gamepad()

print("--- Emulador de Controle Xbox Ativo ---")
print("Pressione 'Shift Direito' para acionar o botão Select (View).")
print("Pressione 'Esc' para fechar o script.")

def on_press(key):
    try:
        # Verifica se a tecla pressionada é o Shift Direito
        if key == keyboard.Key.shift_r:
            print("Botão Select pressionado!")
            # Pressiona o botão VIEW (Select no Xbox)
            gamepad.press_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK)
            gamepad.update()
    except AttributeError:
        pass

def on_release(key):
    # Solta o botão quando a tecla for solta
    if key == keyboard.Key.shift_r:
        gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK)
        gamepad.update()
    
    # Sai do script se pressionar Esc
    if key == keyboard.Key.esc:
        return False

# Inicia o monitoramento do teclado
with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
    listener.join()
