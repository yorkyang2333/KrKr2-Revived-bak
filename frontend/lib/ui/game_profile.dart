class GameProfile {
  String path;
  String name;
  String? coverUrl;
  String? coverLocalPath;

  GameProfile({
    required this.path,
    required this.name,
    this.coverUrl,
    this.coverLocalPath,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'coverUrl': coverUrl,
        'coverLocalPath': coverLocalPath,
      };

  factory GameProfile.fromJson(Map<String, dynamic> json) => GameProfile(
        path: json['path'],
        name: json['name'],
        coverUrl: json['coverUrl'],
        coverLocalPath: json['coverLocalPath'],
      );
}
