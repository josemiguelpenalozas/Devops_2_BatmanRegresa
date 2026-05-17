import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';

// Mock del import de imagen para que jsdom no falle al importar archivos estáticos
vi.mock('../../assets/images/logo2.png', () => ({ default: 'logo2.png' }));

import Footer from '../componentes/Layouts/Footer';

describe('Footer', () => {
  it('debería renderizar la marca "ITPCARGO™"', () => {
    render(<Footer />);
    expect(screen.getByText(/ITPCARGO™/i)).toBeInTheDocument();
  });

  it('debería mostrar el año de copyright 2024', () => {
    render(<Footer />);
    expect(screen.getByText(/2024/i)).toBeInTheDocument();
  });

  it('debería renderizar la sección "Condiciones servicio"', () => {
    render(<Footer />);
    expect(screen.getByText(/Condiciones servicio/i)).toBeInTheDocument();
  });

  it('debería renderizar el link de Instagram', () => {
    render(<Footer />);
    expect(screen.getByText('Instagram')).toBeInTheDocument();
  });

  it('debería renderizar el link de Facebook', () => {
    render(<Footer />);
    expect(screen.getByText('Facebook')).toBeInTheDocument();
  });
});