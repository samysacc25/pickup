using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoPickup.API.Migrations
{
    /// <inheritdoc />
    public partial class CrearTablaOfertas : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "OfertasSolicitud",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    SolicitudId = table.Column<int>(type: "int", nullable: false),
                    ConductorId = table.Column<int>(type: "int", nullable: false),
                    Monto = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
                    Estado = table.Column<int>(type: "int", nullable: false),
                    ConductorLatitud = table.Column<double>(type: "float", nullable: true),
                    ConductorLongitud = table.Column<double>(type: "float", nullable: true),
                    FechaCreacion = table.Column<DateTime>(type: "datetime2", nullable: false),
                    FechaRespuesta = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OfertasSolicitud", x => x.Id);
                    table.ForeignKey(
                        name: "FK_OfertasSolicitud_Conductores_ConductorId",
                        column: x => x.ConductorId,
                        principalTable: "Conductores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_OfertasSolicitud_Solicitudes_SolicitudId",
                        column: x => x.SolicitudId,
                        principalTable: "Solicitudes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_OfertasSolicitud_ConductorId",
                table: "OfertasSolicitud",
                column: "ConductorId");

            migrationBuilder.CreateIndex(
                name: "IX_OfertasSolicitud_SolicitudId_ConductorId",
                table: "OfertasSolicitud",
                columns: new[] { "SolicitudId", "ConductorId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "OfertasSolicitud");
        }
    }
}
