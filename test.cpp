#include <iostream>
#include <mysql.h>

using namespace std;

int main() {
    MYSQL* conn;
    conn = mysql_init(NULL);

  
    if (!mysql_real_connect(conn, "localhost", "root", "alpha", "testdb", 3306, NULL, 0)) {
        cout << "Connection failed: " << mysql_error(conn) << endl;
        return 1;
    }

    cout << "Connected to MySQL!" << endl;


    const char* create_table =
        "CREATE TABLE IF NOT EXISTS users ("
        "id INT AUTO_INCREMENT PRIMARY KEY,"
        "name VARCHAR(50),"
        "age INT"
        ")";

    if (mysql_query(conn, create_table)) {
        cout << "Create table error: " << mysql_error(conn) << endl;
        return 1;
    }

    cout << "Table created!" << endl;

 
    const char* insert1 = "INSERT INTO users (name, age) VALUES ('Shivam', 22)";
    const char* insert2 = "INSERT INTO users (name, age) VALUES ('Rahul', 25)";

    if (mysql_query(conn, insert1) || mysql_query(conn, insert2)) {
        cout << "Insert error: " << mysql_error(conn) << endl;
        return 1;
    }

    cout << "Data inserted!" << endl;

    mysql_close(conn);
    return 0;
}
