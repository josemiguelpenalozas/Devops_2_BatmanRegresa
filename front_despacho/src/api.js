import axios from "axios";

// Instancia para el backend de Despachos (puerto 8081)
// En producción (Docker), nginx redirige /api/despachos/ → backend_despachos:8081
// En desarrollo, el proxy de Vite hace lo mismo
export const apiDespachos = axios.create({
  baseURL: "/api/despachos",
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

// Instancia para el backend de Ventas (puerto 8080)
export const apiVentas = axios.create({
  baseURL: "/api/ventas",
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});