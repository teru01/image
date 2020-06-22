package model

import (
	"time"

	"github.com/jinzhu/gorm"
)

type User struct {
	ID        uint   `json:"id" gorm:"primary_key;auto_increment;not null"`
	Name      string `json:"name" gorm:"type:varchar(255)"`
	Email     string `json:"email" gorm:"type:varchar(255)"`
	Password  string `json:"password" gorm:"type:varchar(255)"`
	Comments  []Comment
	CreatedAt time.Time `json:"created_at"`
}

func CreateUser(db *gorm.DB, user *User) (*User, error) {
	if err := db.Create(user).Error; err != nil {
		return nil, err
	}
	return &User{ID: user.ID, Name: user.Name}, nil
}

func UpdateUser(db *gorm.DB, user *User, m map[string]interface{}) (*User, error) {
	if err := db.Model(user).Update(m).Error; err != nil {
		return nil, err
	}
	return &User{ID: user.ID, Name: user.Name}, nil
}

func DeleteUser(db *gorm.DB, user *User) error {
	return db.Delete(user).Error
}