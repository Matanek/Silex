// One-point preparation adapted from Box2D 3.1.1 contact_solver.c.
// Revision 8c661469c9507d3ad6fbd2fea3f1aa71669c2fe3.
// Copyright (c) 2023 Erin Catto. MIT: Box2D-LICENSE.txt.
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#ifdef SLOT8
#define F(name) float name; uint32_t padding_##name
#define LAYOUT "slots8"
#else
#define F(name) float name
#define LAYOUT "packed4"
#endif
typedef struct {
    F(ma);
    F(mb);
    F(ia);
    F(ib);
    F(nx);
    F(ny);
    F(ax);
    F(ay);
    F(bx);
    F(by);
    F(separation);
    F(vax);
    F(vay);
    F(wa);
    F(vbx);
    F(vby);
    F(wb);
    F(normal);
    F(tangent);
    F(rolling);
    F(friction);
    F(restitution);
    F(tangent_speed);
    F(rolling_resistance);
} Input;
typedef struct {
    F(separation);
    F(normal_mass);
    F(tangent_mass);
    F(relative_velocity);
    F(rolling_mass);
    F(normal);
    F(tangent);
    F(rolling);
    F(friction);
    F(restitution);
    F(tangent_speed);
    F(rolling_resistance);
    F(bias_rate);
    F(mass_scale);
    F(impulse_scale);
    F(nx);
    F(ny);
    F(ax);
    F(ay);
    F(bx);
    F(by);
    F(ma);
    F(mb);
    F(ia);
    F(ib);
    F(total);
} Prepared;
#ifdef SLOT8
_Static_assert(sizeof(Input) == 192, "Silex Input stride");
_Static_assert(sizeof(Prepared) == 208, "Silex Prepared stride");
#endif

Prepared prepare(const Input* in, bool warm)
{
    Prepared out = {0};
    float warm_scale = warm ? 1.0f : 0.0f;
    out.separation = in->separation - ((in->bx - in->ax) * in->nx + (in->by - in->ay) * in->ny);
    float rn_a = in->ax * in->ny - in->ay * in->nx;
    float rn_b = in->bx * in->ny - in->by * in->nx;
    float kn = in->ma + in->mb + in->ia * rn_a * rn_a + in->ib * rn_b * rn_b;
    if (kn > 0.0f) out.normal_mass = 1.0f / kn;
    float tx = in->ny, ty = -in->nx;
    float rt_a = in->ax * ty - in->ay * tx;
    float rt_b = in->bx * ty - in->by * tx;
    float kt = in->ma + in->mb + in->ia * rt_a * rt_a + in->ib * rt_b * rt_b;
    if (kt > 0.0f) out.tangent_mass = 1.0f / kt;
    float kr = in->ia + in->ib;
    if (kr > 0.0f) out.rolling_mass = 1.0f / kr;
    float vax = in->vax, vay = in->vay, wa = in->wa;
    float vbx = in->vbx, vby = in->vby, wb = in->wb;
    if (in->ma == 0.0f) { vax = 0.0f; vay = 0.0f; wa = 0.0f; }
    if (in->mb == 0.0f) { vbx = 0.0f; vby = 0.0f; wb = 0.0f; }
    out.relative_velocity = in->nx * ((vbx - wb * in->by) - (vax - wa * in->ay)) +
        in->ny * ((vby + wb * in->bx) - (vay + wa * in->ax));
    out.normal = warm_scale * in->normal;
    out.tangent = warm_scale * in->tangent;
    out.rolling = warm_scale * in->rolling;
    out.bias_rate = 12.0f; out.mass_scale = 0.75f; out.impulse_scale = 0.25f;
    if (in->ma == 0.0f || in->mb == 0.0f) {
        out.bias_rate = 24.0f; out.mass_scale = 0.875f; out.impulse_scale = 0.125f;
    }
    out.friction = in->friction;
    out.restitution = in->restitution;
    out.tangent_speed = in->tangent_speed;
    out.rolling_resistance = in->rolling_resistance;
    out.nx = in->nx;
    out.ny = in->ny;
    out.ax = in->ax;
    out.ay = in->ay;
    out.bx = in->bx;
    out.by = in->by;
    out.ma = in->ma;
    out.mb = in->mb;
    out.ia = in->ia;
    out.ib = in->ib;
    return out;
}

static Input make_input(int64_t index, int64_t frame)
{
    float k = (float)(index % 16), phase = (float)frame;
    Input in = {.ma = 1.0f, .mb = 0.5f, .ia = 0.25f, .ib = 0.5f, .nx = 0.6f, .ny = 0.8f,
        .ax = 0.125f + phase * 0.0078125f, .ay = -0.0625f,
        .bx = -0.125f, .by = 0.0625f + phase * 0.00390625f,
        .separation = (k - 8.0f) * 0.03125f + phase * 0.001953125f,
        .vax = k * 0.125f, .vay = -0.5f - phase * 0.0625f, .wa = 0.25f,
        .vbx = -0.25f, .vby = k * 0.0625f - 1.0f, .wb = -0.5f + phase * 0.03125f,
        .normal = 0.125f + phase * 0.015625f, .tangent = 0.03125f, .rolling = -0.015625f,
        .friction = (float)(index % 4) * 0.25f, .restitution = k * 0.0625f,
        .tangent_speed = (k - 8.0f) * 0.125f, .rolling_resistance = 0.125f};
    if (index % 4 == 0) { in.ma = 0.0f; in.ia = 0.0f; }
    if (index % 8 == 0) { in.mb = 0.0f; in.ib = 0.0f; }
    if (frame % 2 == 1) { in.nx = 0.8f; in.ny = -0.6f; }
    return in;
}

#ifdef BOX2D_CHECK
#include "body.h"
#include "contact.h"
#include "contact_solver.h"
#include "constraint_graph.h"
#include "world.h"
static void oracle_pass(const Input* inputs, Prepared* outputs, int count, bool warm)
{
    if (count != 16) abort();
    b2ContactSim sims[16] = {0};
    b2ContactConstraint constraints[16] = {0};
    b2BodyState states[32] = {0};
    for (int i = 0; i < count; ++i) {
        Input in = inputs[i];
        states[2*i] = (b2BodyState){.linearVelocity = {in.vax, in.vay}, .angularVelocity = in.wa};
        states[2*i+1] = (b2BodyState){.linearVelocity = {in.vbx, in.vby}, .angularVelocity = in.wb};
        sims[i] = (b2ContactSim){.bodySimIndexA = in.ma == 0.0f ? B2_NULL_INDEX : 2*i,
            .bodySimIndexB = in.mb == 0.0f ? B2_NULL_INDEX : 2*i+1,
            .invMassA = in.ma, .invMassB = in.mb, .invIA = in.ia, .invIB = in.ib,
            .friction = in.friction, .restitution = in.restitution,
            .tangentSpeed = in.tangent_speed, .rollingResistance = in.rolling_resistance,
            .manifold = {.normal = {in.nx, in.ny}, .pointCount = 1, .rollingImpulse = in.rolling,
                .points = {{.anchorA = {in.ax, in.ay}, .anchorB = {in.bx, in.by},
                    .separation = in.separation, .normalImpulse = in.normal, .tangentImpulse = in.tangent}}}};
    }
    b2World world = {.enableWarmStarting = warm};
    b2ConstraintGraph graph = {0};
    graph.colors[B2_OVERFLOW_INDEX].contactSims.data = sims;
    graph.colors[B2_OVERFLOW_INDEX].contactSims.count = count;
    graph.colors[B2_OVERFLOW_INDEX].contactSims.capacity = count;
    graph.colors[B2_OVERFLOW_INDEX].overflowConstraints = constraints;
    b2StepContext context = {.world = &world, .graph = &graph, .states = states,
        .contactSoftness = {12.0f, 0.75f, 0.25f}, .staticSoftness = {24.0f, 0.875f, 0.125f}};
    b2PrepareOverflowContacts(&context);
    for (int i = 0; i < count; ++i) {
        b2ContactConstraint c = constraints[i];
        b2ContactConstraintPoint p = c.points[0];
        outputs[i] = (Prepared){.separation = p.baseSeparation, .normal_mass = p.normalMass,
            .tangent_mass = p.tangentMass, .relative_velocity = p.relativeVelocity,
            .rolling_mass = c.rollingMass, .normal = p.normalImpulse, .tangent = p.tangentImpulse,
            .rolling = c.rollingImpulse, .friction = c.friction, .restitution = c.restitution,
            .tangent_speed = c.tangentSpeed, .rolling_resistance = c.rollingResistance,
            .bias_rate = c.softness.biasRate, .mass_scale = c.softness.massScale,
            .impulse_scale = c.softness.impulseScale, .nx = c.normal.x, .ny = c.normal.y,
            .ax = p.anchorA.x, .ay = p.anchorA.y, .bx = p.anchorB.x, .by = p.anchorB.y,
            .ma = c.invMassA, .mb = c.invMassB, .ia = c.invIA, .ib = c.invIB,
            .total = p.totalNormalImpulse};
    }
}
#endif

static double seconds(void)
{
    struct timespec t;
    if (clock_gettime(CLOCK_MONOTONIC, &t) != 0) abort();
    return (double)t.tv_sec + (double)t.tv_nsec * 1e-9;
}

int main(int argc, char** argv)
{
    bool full = argc > 1 && strcmp(argv[1], "--check-full") == 0;
    bool check = full || (argc > 1 && strcmp(argv[1], "--check") == 0);
#ifdef BOX2D_CHECK
    if (!check) abort();
#endif
    int64_t count = check ? 16 : 8192, passes = check && !full ? 8 : 2048;
    Input* inputs = calloc((size_t)count * 16, sizeof(Input));
    Prepared* outputs = calloc((size_t)count, sizeof(Prepared));
    if (!inputs || !outputs) abort();
    for (int64_t frame = 0; frame < 16; ++frame)
        for (int64_t i = 0; i < count; ++i) inputs[frame * count + i] = make_input(i, frame);
    double signature = 0.0, start = seconds();
    for (int64_t pass = 0; pass < passes; ++pass) {
        int64_t base = (pass % 16) * count;
#ifdef BOX2D_CHECK
        oracle_pass(inputs + base, outputs, (int)count, pass % 2 == 0);
#else
        for (int64_t i = 0; i < count; ++i) {
            if (base + i < 0 || base + i >= count * 16) abort();
            outputs[i] = prepare(inputs + base + i, pass % 2 == 0);
        }
#endif
        for (int64_t i = 0; i < count; ++i) {
            Prepared v = outputs[i];
            if (check) {
                printf("STATE %lld %lld %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g %.9g\n",
                    (long long)pass, (long long)i, v.separation, v.normal_mass, v.tangent_mass, v.relative_velocity, v.rolling_mass, v.normal, v.tangent, v.rolling, v.friction, v.restitution, v.tangent_speed, v.rolling_resistance, v.bias_rate, v.mass_scale, v.impulse_scale, v.nx, v.ny, v.ax, v.ay, v.bx, v.by, v.ma, v.mb, v.ia, v.ib, v.total);
            } else {
                signature += (double)(v.separation * 1.0f +
                    v.normal_mass * 2.0f +
                    v.tangent_mass * 3.0f +
                    v.relative_velocity * 4.0f +
                    v.rolling_mass * 5.0f +
                    v.normal * 6.0f +
                    v.tangent * 7.0f +
                    v.rolling * 8.0f +
                    v.friction * 9.0f +
                    v.restitution * 10.0f +
                    v.tangent_speed * 11.0f +
                    v.rolling_resistance * 12.0f +
                    v.bias_rate * 13.0f +
                    v.mass_scale * 14.0f +
                    v.impulse_scale * 15.0f +
                    v.nx * 16.0f +
                    v.ny * 17.0f +
                    v.ax * 18.0f +
                    v.ay * 19.0f +
                    v.bx * 20.0f +
                    v.by * 21.0f +
                    v.ma * 22.0f +
                    v.mb * 23.0f +
                    v.ia * 24.0f +
                    v.ib * 25.0f +
                    v.total * 26.0f);
            }
        }
    }
    if (!check) printf("KERNEL preparation clang " LAYOUT " %lld %lld %.9f %.17g\n",
        (long long)count, (long long)passes, (seconds() - start) * 1000.0, signature);
    free(outputs); free(inputs);
    return 0;
}
