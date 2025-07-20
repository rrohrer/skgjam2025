const rl = @import("raylib");
const std = @import("std");

pub const Entity = struct {
    const Self = @This();
    const Id = usize;

    // gloabal counter of entities so that the are always unique.
    var current_id: Id = 0;

    id: Id,
    data: Data,
    position: rl.Vector2,
    scale: rl.Vector2,

    pub const Type = enum {
        Barrel,
        Floor,
        Wall,
        Player,
        Reaper,
        Bullet,
    };

    pub const BulletData = struct {
        damage: i32,
        direction: rl.Vector2,
        speed: f32,
        color: rl.Color,
        lifetime: f32,
        dt: f32,

        pub fn init(direction: rl.Vector2) BulletData {
            return BulletData{
                .damage = 10,
                .direction = direction,
                .speed = 400,
                .color = rl.Color.init(255, 72, 73, 255),
                .lifetime = 0.5,
                .dt = 0,
            };
        }
    };

    pub const PlayerData = struct {
        health: i32,
        move_speed: f32,
        dt_shoot: f32,
        shoot_speed: f32,
        color: rl.Color,

        pub fn init() PlayerData {
            const shoot_speed = 0.05;
            return PlayerData{
                .health = 100,
                .move_speed = 200,
                .dt_shoot = shoot_speed,
                .shoot_speed = shoot_speed,
                .color = rl.Color.init(72, 255, 185, 255),
            };
        }
    };

    pub const Data = union(Type) {
        Barrel: void,
        Floor: void,
        Wall: void,
        Player: PlayerData,
        Reaper: void,
        Bullet: BulletData,

        pub fn initPlayer() Data {
            return Data{ .Player = PlayerData.init() };
        }

        pub fn initBullet(direction: rl.Vector2) Data {
            return Data{ .Bullet = BulletData.init(direction) };
        }
    };

    pub fn init(data: Data, position: rl.Vector2, scale: rl.Vector2) Self {
        const id = current_id;
        current_id += 1;
        return Entity{ .data = data, .position = position, .scale = scale, .id = id };
    }
};
