import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import userEvent from '@testing-library/user-event';
import { Modal } from '../componentes/CrudAdmin/Modal';

describe('Modal', () => {
  it('debería renderizar el contenido hijo (children) cuando está abierto', () => {
    render(
      <Modal open={true} onClose={vi.fn()}>
        <p>Contenido del modal</p>
      </Modal>
    );
    expect(screen.getByText('Contenido del modal')).toBeInTheDocument();
  });

  it('debería mostrar el botón de cierre "X"', () => {
    render(
      <Modal open={true} onClose={vi.fn()}>
        <p>Contenido</p>
      </Modal>
    );
    expect(screen.getByRole('button', { name: /X/i })).toBeInTheDocument();
  });

  it('debería llamar a onClose al hacer click en el botón X', async () => {
    const handleClose = vi.fn();
    render(
      <Modal open={true} onClose={handleClose}>
        <p>Contenido</p>
      </Modal>
    );
    await userEvent.click(screen.getByRole('button', { name: /X/i }));
    expect(handleClose).toHaveBeenCalledTimes(1);
  });

  it('debería tener clase "invisible" cuando está cerrado', () => {
    const { container } = render(
      <Modal open={false} onClose={vi.fn()}>
        <p>Oculto</p>
      </Modal>
    );
    // El div exterior debería tener clase invisible cuando open=false
    const overlay = container.firstChild;
    expect(overlay).toHaveClass('invisible');
  });
});