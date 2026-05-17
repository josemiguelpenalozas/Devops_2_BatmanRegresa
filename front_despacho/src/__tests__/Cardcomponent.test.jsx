import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import userEvent from '@testing-library/user-event';
import { CardComponent } from '../componentes/CrudAdmin/CardComponent';

describe('CardComponent', () => {
  const propsBase = {
    title: 'Consultar Ordenes',
    description: 'Descripción de prueba',
    buttonText: 'Consultar',
    onClick: vi.fn(),
  };

  it('debería renderizar el título recibido por props', () => {
    render(<CardComponent {...propsBase} />);
    expect(screen.getByText('Consultar Ordenes')).toBeInTheDocument();
  });

  it('debería renderizar la descripción recibida por props', () => {
    render(<CardComponent {...propsBase} />);
    expect(screen.getByText('Descripción de prueba')).toBeInTheDocument();
  });

  it('debería renderizar el texto del botón', () => {
    render(<CardComponent {...propsBase} />);
    expect(screen.getByRole('button', { name: /Consultar/i })).toBeInTheDocument();
  });

  it('debería llamar a onClick cuando se hace click en el botón', async () => {
    const handleClick = vi.fn();
    render(<CardComponent {...propsBase} onClick={handleClick} />);
    const boton = screen.getByRole('button', { name: /Consultar/i });
    await userEvent.click(boton);
    expect(handleClick).toHaveBeenCalledTimes(1);
  });
});