import type { AlertButton } from 'react-native';

export const Alert = {
  alert(title: string, message = '', buttons: AlertButton[] = [{ text: 'OK' }]) {
    const actions = buttons.filter(button => button.style !== 'cancel');
    if (actions.length === 0) return;
    if (actions.length === 1) {
      if (window.confirm(`${title}\n${message}`)) actions[0].onPress?.();
      return;
    }
    const answer = window.prompt(`${title}\n${message}\n\n${actions.map((action, index) => `${index + 1}. ${action.text}`).join('\n')}\n\nCancelar: deixe vazio`);
    if (answer && /^[1-9]\d*$/.test(answer)) actions[Number(answer) - 1]?.onPress?.();
  },
};
