#include <cstdint>
#include <cstdio>
#include <vector>

namespace {

struct Sample {
    float positionX { 0.0F };
    float positionY { 0.0F };
    float velocityX { 0.0F };
    float velocityY { 0.0F };
};

struct Steering {
    float x { 0.0F };
    float y { 0.0F };
};

std::vector<Sample> makeSamples(std::int64_t count) {
    std::vector<Sample> samples;
    samples.reserve(static_cast<std::size_t>(count));
    for (std::int64_t index = 0; index < count; ++index) {
        samples.push_back({
            static_cast<float>(index % 97) * 7.0F,
            static_cast<float>(index % 89) * 5.0F,
            static_cast<float>(index % 13) + 55.0F,
            static_cast<float>(index % 17) - 8.0F
        });
    }
    return samples;
}

float calculate(const std::vector<Sample>& samples, std::int64_t rounds) {
    float checksum = 0.0F;
    for (std::int64_t round = 0; round < rounds; ++round) {
        const float bias = static_cast<float>(round) * 0.001F;
        for (const Sample& boid : samples) {
            float separationX = 0.0F;
            float separationY = 0.0F;
            float centerX = 0.0F;
            float centerY = 0.0F;
            float headingX = 0.0F;
            float headingY = 0.0F;
            std::int64_t neighbors = 0;

            for (const Sample& other : samples) {
                const float offsetX = boid.positionX + bias - other.positionX;
                const float offsetY = boid.positionY - other.positionY;
                const float distanceSquared = offsetX * offsetX + offsetY * offsetY;
                if (distanceSquared > 0.0F && distanceSquared < 5'184.0F) {
                    centerX += other.positionX;
                    centerY += other.positionY;
                    headingX += other.velocityX;
                    headingY += other.velocityY;
                    ++neighbors;
                    if (distanceSquared < 784.0F) {
                        const float divisor = distanceSquared > 1.0F
                            ? distanceSquared
                            : 1.0F;
                        separationX += offsetX / divisor;
                        separationY += offsetY / divisor;
                    }
                }
            }

            if (neighbors > 0) {
                const float count = static_cast<float>(neighbors);
                checksum += (centerX / count - boid.positionX) * 0.35F
                    + (centerY / count - boid.positionY) * 0.35F
                    + (headingX / count - boid.velocityX) * 0.8F
                    + (headingY / count - boid.velocityY) * 0.8F
                    + separationX * 1400.0F
                    + separationY * 1400.0F;
            }
        }
    }
    return checksum;
}

Steering steer(const Sample& boid, const std::vector<Sample>& samples) {
    float separationX = 0.0F;
    float separationY = 0.0F;
    float centerX = 0.0F;
    float centerY = 0.0F;
    float headingX = 0.0F;
    float headingY = 0.0F;
    std::int64_t neighbors = 0;

    for (const Sample& other : samples) {
        const float offsetX = boid.positionX - other.positionX;
        const float offsetY = boid.positionY - other.positionY;
        const float distanceSquared = offsetX * offsetX + offsetY * offsetY;
        if (distanceSquared > 0.0F && distanceSquared < 5'184.0F) {
            centerX += other.positionX;
            centerY += other.positionY;
            headingX += other.velocityX;
            headingY += other.velocityY;
            ++neighbors;
            if (distanceSquared < 784.0F) {
                const float divisor = distanceSquared > 1.0F
                    ? distanceSquared
                    : 1.0F;
                separationX += offsetX / divisor;
                separationY += offsetY / divisor;
            }
        }
    }

    if (neighbors == 0) {
        return {};
    }
    const float count = static_cast<float>(neighbors);
    return {
        (centerX / count - boid.positionX) * 0.35F
            + (headingX / count - boid.velocityX) * 0.8F
            + separationX * 1400.0F,
        (centerY / count - boid.positionY) * 0.35F
            + (headingY / count - boid.velocityY) * 0.8F
            + separationY * 1400.0F
    };
}

float moveOnce(
    std::vector<Sample>& bodies,
    const std::vector<Sample>& snapshot,
    float delta
) {
    float checksum = 0.0F;
    for (Sample& boid : bodies) {
        const Steering acceleration = steer(boid, snapshot);
        boid.velocityX += acceleration.x * delta;
        boid.velocityY += acceleration.y * delta;
        boid.positionX += boid.velocityX * delta;
        boid.positionY += boid.velocityY * delta;
        checksum += boid.positionX + boid.positionY;
    }
    return checksum;
}

float steerAll(const std::vector<Sample>& samples, std::int64_t rounds) {
    float checksum = 0.0F;
    for (std::int64_t round = 0; round < rounds; ++round) {
        for (const Sample& boid : samples) {
            const Steering acceleration = steer(boid, samples);
            checksum += acceleration.x + acceleration.y;
        }
    }
    return checksum;
}

} // namespace

int main() {
    const auto snapshot = makeSamples(1'000);
    auto bodies = makeSamples(1'000);
    const bool calculationOk = calculate(snapshot, 32) > 0.0F;
    const float steeringChecksum = steerAll(snapshot, 256);
    const bool steeringOk = steeringChecksum == steeringChecksum;
    const bool motionOk = moveOnce(bodies, snapshot, 1.0F / 120.0F) > 0.0F
        && bodies[0].positionX != snapshot[0].positionX;
    std::printf(
        "%s\n",
        calculationOk && steeringOk && motionOk ? "true" : "false"
    );
}
