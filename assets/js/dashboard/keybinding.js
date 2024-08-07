/* @format */
import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef
} from 'react'
import { useAppNavigate } from './navigation/use-app-navigate'

/**
 * Returns whether a keydown or keyup event should be ignored or not.
 *
 * Keybindings are ignored when a modifier key is pressed, for example, if the
 * keybinding is <i>, but the user pressed <Ctrl-i> or <Meta-i>, the event
 * should be discarded.
 *
 * Another case for ignoring a keybinding, is when the user is typing into a
 * form, and presses the keybinding. For example, if the keybinding is <p> and
 * the user types <apple>, the event should also be discarded.
 *
 * @param {*} event - Captured HTML DOM event
 * @return {boolean} Whether the event should be ignored or not.
 *
 */
export function shouldIgnoreKeypress(event) {
  const modifierPressed =
    event.ctrlKey || event.metaKey || event.altKey || event.keyCode == 229
  const isTyping =
    event.isComposing ||
    event.target.tagName == 'INPUT' ||
    event.target.tagName == 'TEXTAREA'

  return modifierPressed || isTyping
}

/**
 * Returns whether the given keybinding has been pressed and should be
 * processed. Events can be ignored based on `shouldIgnoreKeypress(event)`.
 *
 * @param {string} keybinding - The target key to checked, e.g. `"i"`.
 * @return {boolean} Whether the event should be processed or not.
 *
 */
export function isKeyPressed(event, keybinding) {
  const keyPressed = event.key.toLowerCase() == keybinding.toLowerCase()
  return keyPressed && !shouldIgnoreKeypress(event)
}

const keybindsContextDefaultValue = {
  registerKeybind: () => {},
  deregisterKeybind: () => {}
}

const KeybindsContext = createContext(keybindsContextDefaultValue)

const getAccessor = ({ key, type }) =>
  JSON.stringify({ key: key.toLowerCase(), type })
const parseAccessor = (accessor) => JSON.parse(accessor)

export function KeybindsContextProvider({ children }) {
  const keybindsRef = useRef(new Map())

  const registerKeybind = useCallback(({ key, type, handler }) => {
    const accessor = getAccessor({ key, type })

    const existingHandler = keybindsRef.current.get(accessor)

    if (existingHandler) {
      throw new Error(`Keybind already present for ${accessor}`)
    }

    const wrappedHandler = (event) => {
      if (isKeyPressed(event, key)) {
        handler()
      }
    }

    keybindsRef.current.set(accessor, wrappedHandler)
    document.addEventListener(type, wrappedHandler)

    return accessor
  }, [])

  const deregisterKeybind = useCallback((accessor) => {
    const existingKeybind = keybindsRef.current.get(accessor)

    if (existingKeybind) {
      try {
        const { _key, type } = parseAccessor(accessor)
        document.removeEventListener(type, existingKeybind)
        keybindsRef.current.delete(accessor)
        return true
      } catch (e) {
        console.warn(`Error deregistering keybind for ${accessor}`, e)
      }
    }

    return false
  }, [])

  return (
    <KeybindsContext.Provider value={{ registerKeybind, deregisterKeybind }}>
      {children}
    </KeybindsContext.Provider>
  )
}

export function useKeybindsContext() {
  return useContext(KeybindsContext)
}

export function Keybind({ keyboardKey, type, handler }) {
  const { registerKeybind, deregisterKeybind } = useKeybindsContext()

  useEffect(() => {
    const accessor = registerKeybind({
      key: keyboardKey,
      type,
      handler: handler
    })
    return () => deregisterKeybind(accessor)
  }, [registerKeybind, deregisterKeybind, keyboardKey, type, handler])

  return null
}

export function NavigateKeybind({ keyboardKey, type, navigateProps }) {
  const navigate = useAppNavigate()
  const handler = useCallback(() => {
    navigate({ ...navigateProps })
  }, [navigateProps, navigate])

  return <Keybind keyboardKey={keyboardKey} type={type} handler={handler} />
}

export function KeybindHint({ children }) {
  return (
    <kbd className="rounded border border-gray-200 dark:border-gray-600 px-2 font-mono font-normal text-xs text-gray-400">
      {children}
    </kbd>
  )
}
