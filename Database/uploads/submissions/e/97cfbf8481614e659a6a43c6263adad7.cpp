#include <iostream>
#include <string>
#include <vector>
using namespace std;

int main()
{
    vector<int> vec;
    vec[1000] = 1;
    throw std::out_of_range("Index out of range");
}