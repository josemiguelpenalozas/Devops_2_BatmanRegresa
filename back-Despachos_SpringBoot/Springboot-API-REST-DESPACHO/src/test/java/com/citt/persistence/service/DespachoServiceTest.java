package com.citt.persistence.service;

import com.citt.exceptions.DespachoNotFoundException;
import com.citt.persistence.entity.Despacho;
import com.citt.persistence.repository.DespachoRepository;
import com.citt.persistence.services.DespachoServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class DespachoServiceTest {

    @Mock
    private DespachoRepository despachoRepository;

    @InjectMocks
    private DespachoServiceImpl despachoService;

    private Despacho despacho;

    @BeforeEach
    public void setUp() {
        despacho = new Despacho(
                1L,
                LocalDate.of(2025, 4, 14),
                "ABCD12",
                1,
                100L,
                "Av. Siempre Viva 742",
                50000L,
                false
        );
    }

    @Test
    @DisplayName("Cuando se guarda un despacho válido, entonces se persiste correctamente")
    public void whenSavingValidDespacho_thenItIsPersistedCorrectly() {
        when(despachoRepository.save(any(Despacho.class))).thenReturn(despacho);

        Despacho saved = despachoService.saveDespacho(despacho);

        verify(despachoRepository, times(1)).save(despacho);
        assertNotNull(saved);
        assertEquals(despacho.getDireccionCompra(), saved.getDireccionCompra());
        assertEquals(despacho.getPatenteCamion(), saved.getPatenteCamion());
        assertEquals(despacho.getValorCompra(), saved.getValorCompra());
    }

    @Test
    @DisplayName("Cuando se busca un despacho por ID existente, entonces se retorna correctamente")
    public void whenFindingById_thenReturnsDespacho() throws DespachoNotFoundException {
        when(despachoRepository.findById(1L)).thenReturn(Optional.of(despacho));

        Despacho found = despachoService.findById(1L);

        assertNotNull(found);
        assertEquals(1L, found.getIdDespacho());
        assertEquals("ABCD12", found.getPatenteCamion());
    }

    @Test
    @DisplayName("Cuando se busca un ID que no existe, entonces lanza DespachoNotFoundException")
    public void whenFindingByNonExistentId_thenThrowsException() {
        when(despachoRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(DespachoNotFoundException.class, () -> despachoService.findById(99L));
    }

    @Test
    @DisplayName("Cuando se listan todos los despachos, entonces retorna la lista completa")
    public void whenFindingAllDespachos_thenReturnsFullList() {
        List<Despacho> lista = List.of(despacho, new Despacho());
        when(despachoRepository.findAll()).thenReturn(lista);

        List<Despacho> result = despachoService.findAllDespachos();

        assertEquals(2, result.size());
        verify(despachoRepository, times(1)).findAll();
    }
}