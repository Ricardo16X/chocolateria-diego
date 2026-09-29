<?php

namespace Tests\Unit;

use App\Models\Clientes\DetallePedido;
use App\Models\Clientes\DireccionEntrega;
use App\Models\Clientes\Pedido;
use App\Models\Fel\DocumentoFel;
use App\Models\Inventario\Existencia;
use App\Models\PuntoVenta\DetalleVenta;
use App\Models\PuntoVenta\Venta;
use App\Models\Seguridad\Usuario;
use Illuminate\Database\Eloquent\Model;
use PHPUnit\Framework\TestCase;

// Casos U09 a U13 del plan de pruebas.
//
// El esquema de docker/mysql/init/01_esquema.sql es la unica fuente de
// verdad del modelo de datos, y los modelos Eloquent se mapean contra el a
// mano. Estas pruebas verifican las reglas del mapeo sin tocar la base de
// datos: solo leen la configuracion declarada en cada modelo.
//
// Sirven como red de seguridad contra el error mas probable de este
// proyecto: que alguien agregue una columna a $fillable sin darse cuenta de
// que MySQL la calcula sola, o que renombre una tabla siguiendo las
// convenciones de Laravel en vez de las del esquema.
class ModelosContraEsquemaTest extends TestCase
{
    /**
     * Las siete columnas GENERATED ALWAYS del esquema, con el modelo que
     * mapea su tabla. MySQL rechaza cualquier INSERT o UPDATE que intente
     * escribirlas, asi que ninguna puede estar en $fillable.
     *
     * @return array<string, array{class-string<Model>, string}>
     */
    public static function columnasGeneradas(): array
    {
        return [
            'existencia.lote_clave' => [Existencia::class, 'lote_clave'],
            'direccion_entrega.predeterminada_clave' => [DireccionEntrega::class, 'predeterminada_clave'],
            'pedido.total' => [Pedido::class, 'total'],
            'detalle_pedido.subtotal_linea' => [DetallePedido::class, 'subtotal_linea'],
            'venta.total' => [Venta::class, 'total'],
            'detalle_venta.subtotal_linea' => [DetalleVenta::class, 'subtotal_linea'],
            'documento_fel.factura_clave' => [DocumentoFel::class, 'factura_clave'],
        ];
    }

    /**
     * U09
     *
     * @dataProvider columnasGeneradas
     */
    public function test_U09_una_columna_generada_por_mysql_nunca_es_asignable_en_masa(string $modelo, string $columna): void
    {
        $instancia = new $modelo;

        $this->assertNotContains(
            $columna,
            $instancia->getFillable(),
            "{$modelo} declara '{$columna}' en \$fillable, pero MySQL la calcula sola y rechaza cualquier escritura."
        );
    }

    /**
     * U10
     *
     * @dataProvider columnasGeneradas
     */
    public function test_U10_una_columna_generada_por_mysql_no_pasa_el_filtro_de_asignacion(string $modelo, string $columna): void
    {
        // La comprobacion anterior lee la declaracion; esta ejercita el
        // comportamiento real de Eloquent, que es lo que protege de verdad.
        $instancia = new $modelo;
        $instancia->fill([$columna => 1]);

        $this->assertArrayNotHasKey(
            $columna,
            $instancia->getAttributes(),
            "Eloquent acepto escribir '{$columna}' en {$modelo}; MySQL lo rechazaria al guardar."
        );
    }

    /**
     * Cada modelo con su tabla, tal como se llama en el esquema.
     *
     * @return array<string, array{class-string<Model>, string, string}>
     */
    public static function tablasYLlaves(): array
    {
        return [
            'usuario' => [Usuario::class, 'usuario', 'id_usuario'],
            'venta' => [Venta::class, 'venta', 'id_venta'],
            'detalle_venta' => [DetalleVenta::class, 'detalle_venta', 'id_detalle_venta'],
            'pedido' => [Pedido::class, 'pedido', 'id_pedido'],
            'existencia' => [Existencia::class, 'existencia', 'id_existencia'],
            'documento_fel' => [DocumentoFel::class, 'documento_fel', 'id_documento_fel'],
        ];
    }

    /**
     * U11
     *
     * @dataProvider tablasYLlaves
     */
    public function test_U11_el_modelo_apunta_a_la_tabla_y_la_llave_del_esquema(string $modelo, string $tabla, string $llave): void
    {
        // Sin $table explicito, Laravel pluralizaria en ingles: 'ventas',
        // 'usuarios'. El esquema esta en espanol y en singular.
        $instancia = new $modelo;

        $this->assertSame($tabla, $instancia->getTable());
        $this->assertSame($llave, $instancia->getKeyName());
    }

    /**
     * U12
     *
     * @dataProvider tablasYLlaves
     */
    public function test_U12_ningun_modelo_espera_las_columnas_de_marca_de_tiempo_de_laravel(string $modelo): void
    {
        // Ninguna tabla del esquema tiene created_at ni updated_at. Con
        // $timestamps activo, Eloquent intentaria escribirlas y fallaria.
        $instancia = new $modelo;

        $this->assertFalse(
            $instancia->usesTimestamps(),
            "{$modelo} tiene \$timestamps activo, pero su tabla no tiene created_at ni updated_at."
        );
    }

    /** U13 */
    public function test_U13_el_usuario_autentica_contra_contrasena_hash_y_no_la_expone(): void
    {
        // La columna se llama contrasena_hash, no 'password'. El guard de
        // Laravel lo sabe por getAuthPassword(), y $hidden evita que el hash
        // salga en una respuesta JSON.
        $usuario = new Usuario;
        $usuario->contrasena_hash = '$2y$10$hashdeprueba';

        $this->assertSame('$2y$10$hashdeprueba', $usuario->getAuthPassword());
        $this->assertContains('contrasena_hash', $usuario->getHidden());
        $this->assertArrayNotHasKey('contrasena_hash', $usuario->toArray());
    }
}
