using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoPickup.API.Migrations
{
    /// <inheritdoc />
    public partial class InicialCompleta : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CodigosVerificacionTelefono",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Telefono = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Codigo = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "datetime2", nullable: false),
                    FechaExpiracion = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Verificado = table.Column<bool>(type: "bit", nullable: false),
                    FechaVerificacion = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Intentos = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CodigosVerificacionTelefono", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Usuarios",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    NombreCompleto = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Correo = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Telefono = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    ClaveHash = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Rol = table.Column<int>(type: "int", nullable: false),
                    Activo = table.Column<bool>(type: "bit", nullable: false),
                    FotoPerfilUrl = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    TelefonoVerificado = table.Column<bool>(type: "bit", nullable: false),
                    TokenPushNotificacion = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    RecargoPendiente = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
                    FechaRegistro = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Usuarios", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Conductores",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    NumeroCedula = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    TipoLicencia = table.Column<int>(type: "int", nullable: false),
                    FotoLicenciaFrontalUrl = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    EstadoSolicitud = table.Column<int>(type: "int", nullable: false),
                    MotivoRechazo = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    FechaRevision = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Estado = table.Column<int>(type: "int", nullable: false),
                    UltimaLatitud = table.Column<double>(type: "float", nullable: true),
                    UltimaLongitud = table.Column<double>(type: "float", nullable: true),
                    UltimaActualizacionUbicacion = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CalificacionPromedio = table.Column<double>(type: "float", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Conductores", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Conductores_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Solicitudes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ClienteId = table.Column<int>(type: "int", nullable: false),
                    ConductorId = table.Column<int>(type: "int", nullable: true),
                    OrigenLatitud = table.Column<double>(type: "float", nullable: false),
                    OrigenLongitud = table.Column<double>(type: "float", nullable: false),
                    OrigenDireccion = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    DestinoLatitud = table.Column<double>(type: "float", nullable: false),
                    DestinoLongitud = table.Column<double>(type: "float", nullable: false),
                    DestinoDireccion = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    DescripcionCarga = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    LlevaCarga = table.Column<bool>(type: "bit", nullable: false),
                    EsInterprovincial = table.Column<bool>(type: "bit", nullable: false),
                    TipoCamionetaRequerida = table.Column<int>(type: "int", nullable: false),
                    Estado = table.Column<int>(type: "int", nullable: false),
                    TarifaSugerida = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
                    TarifaPropuestaCliente = table.Column<decimal>(type: "decimal(10,2)", nullable: true),
                    TarifaAcordada = table.Column<decimal>(type: "decimal(10,2)", nullable: true),
                    TarifaFinal = table.Column<decimal>(type: "decimal(10,2)", nullable: true),
                    RecargoAplicado = table.Column<decimal>(type: "decimal(10,2)", nullable: true),
                    MetodoPago = table.Column<int>(type: "int", nullable: false),
                    DistanciaKm = table.Column<double>(type: "float", nullable: true),
                    DuracionEstimadaMin = table.Column<int>(type: "int", nullable: true),
                    CalificacionConductor = table.Column<int>(type: "int", nullable: true),
                    CalificacionCliente = table.Column<int>(type: "int", nullable: true),
                    NotificadoLlegada = table.Column<bool>(type: "bit", nullable: false),
                    FechaSolicitud = table.Column<DateTime>(type: "datetime2", nullable: false),
                    FechaAceptacion = table.Column<DateTime>(type: "datetime2", nullable: true),
                    FechaInicio = table.Column<DateTime>(type: "datetime2", nullable: true),
                    FechaFin = table.Column<DateTime>(type: "datetime2", nullable: true),
                    FechaCancelacion = table.Column<DateTime>(type: "datetime2", nullable: true),
                    MotivoCancelacion = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Solicitudes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Solicitudes_Conductores_ConductorId",
                        column: x => x.ConductorId,
                        principalTable: "Conductores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Solicitudes_Usuarios_ClienteId",
                        column: x => x.ClienteId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Vehiculos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Placa = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    Marca = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Modelo = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Color = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Anio = table.Column<int>(type: "int", nullable: false),
                    TipoCamioneta = table.Column<int>(type: "int", nullable: false),
                    DescripcionCapacidad = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: true),
                    FotoLateralUrl = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    FotoFrontalUrl = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    FotoCabinaUrl = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ConductorId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Vehiculos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Vehiculos_Conductores_ConductorId",
                        column: x => x.ConductorId,
                        principalTable: "Conductores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Conductores_UsuarioId",
                table: "Conductores",
                column: "UsuarioId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Solicitudes_ClienteId",
                table: "Solicitudes",
                column: "ClienteId");

            migrationBuilder.CreateIndex(
                name: "IX_Solicitudes_ConductorId",
                table: "Solicitudes",
                column: "ConductorId");

            migrationBuilder.CreateIndex(
                name: "IX_Usuarios_Correo",
                table: "Usuarios",
                column: "Correo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Vehiculos_ConductorId",
                table: "Vehiculos",
                column: "ConductorId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Vehiculos_Placa",
                table: "Vehiculos",
                column: "Placa",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CodigosVerificacionTelefono");

            migrationBuilder.DropTable(
                name: "Solicitudes");

            migrationBuilder.DropTable(
                name: "Vehiculos");

            migrationBuilder.DropTable(
                name: "Conductores");

            migrationBuilder.DropTable(
                name: "Usuarios");
        }
    }
}
