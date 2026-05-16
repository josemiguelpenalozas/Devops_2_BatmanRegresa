import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import Navbar from '../componentes/Layouts/Navbar';

describe('Navbar', () => {
  it('debería renderizar el título "Despacho Dashboard"', () => {
    render(<Navbar />);
    const titulo = screen.getByText('Despacho Dashboard');
    expect(titulo).toBeInTheDocument();
  });

  it('debería mostrar los links de navegación principales', () => {
    render(<Navbar />);
    expect(screen.getByText('Usuarios')).toBeInTheDocument();
    expect(screen.getByText('Productos')).toBeInTheDocument();
    expect(screen.getByText('Configuración')).toBeInTheDocument();
  });

  it('el título debería ser un elemento h2', () => {
    render(<Navbar />);
    const titulo = screen.getByRole('heading', { level: 2 });
    expect(titulo).toHaveTextContent('Despacho Dashboard');
  });
});